{ config, options, name, ... }:
let
  inherit (import <nixpkgs/lib>)
    types mkOption replaceChars optionalString range mapAttrs;
  inherit (import <microgram/sdk.nix>) sdk lib;


  # Convert time periods (e.g. "1h") to seconds
  toSeconds = p: with builtins;
    let
      count = let
        count' = substring 0 (stringLength p - 1) p;
      in if count' == "" then 0 else fromJSON count';
      unit = substring (stringLength p - 1) 1 p ;
      conv = mapAttrs (_: mul) {
        s = 1; m = 60; h = 3600; d = 86400;
      } // (listToAttrs
        (map (n: { name = toString n; value = (x: x * 10 + n); }) (range 0 9))
      );
    in if conv ? "${unit}" then conv.${unit} count
       else throw "Invalid period ${p}";

  max = a: b: if a > b then a else b;

  writeBashScript = n: c: sdk.writeScript n ''
    #!${sdk.bash}/bin/bash
    set -e
    set -o pipefail
    ${c}
  '';

  shellImpl = check:
    let
      timeout = toString (toSeconds check.timeout);
      timeoutCmd = "timeout ${timeout}";
      zero-is-ok = zero-is-fine: optionalString zero-is-fine
      ''
        if declare -F humanize_zero_is_ok >/dev/null; then
          humanize_zero_is_ok
        fi
      '';
      # Sleep a bit to allow data to flow back from the possibly remote target
      memcached-get = key: target: sdk.writeBashScript "memcached-get.sh" ''
        (echo get ${key} && sleep 1) \
        | ${timeoutCmd} ${sdk.netcat-openbsd}/bin/nc ${replaceChars [":"] [" "] target}
      '';
    in
    if check.http-ok != null then ''
        metric=0
        curl --max-time ${timeout} -f -sS -o /dev/null "${check.http-ok}" || metric=$?
        ${zero-is-ok true}
      ''
    else if check.mysql-metric != null then ''
        metric=$(${timeoutCmd} ${sdk.mariadb}/bin/mysql -h 127.0.0.1 -qrN -B < ${builtins.toFile "mysql-metric" check.mysql-metric})
        ${zero-is-ok (check.zero-is-fine or false)}
      ''
    else if check.mysql-status != null then ''
        metric=$(${timeoutCmd} ${sdk.mariadb}/bin/mysql -h 127.0.0.1 -qrN -B < ${builtins.toFile "mysql-status" ''
            select variable_value from information_schema.global_status where variable_name = '${check.mysql-status}'
        ''})
      ''
    else if check.memcached-stat != null then let inherit (check.memcached-stat) key target; in ''
        metric=$(${timeoutCmd} ${sdk.memcached-tool}/bin/memcached-tool ${target} stats | awk '$1 == "${key}" {print $2}')
      ''
    else if check.memcached-kvmetric != null then let inherit (check.memcached-kvmetric) key target; in ''
      metric=$(${memcached-get key target} \
                | awk '/^VALUE/ {exists=1; next}  exists { print $1; exit }')
      ''
    else if check.memcached-kvmetric-exists != null then let inherit (check.memcached-kvmetric-exists) key target; in ''
      metric=$(${memcached-get key target} \
                | awk -v exists=1 '/^VALUE/ {exists=0; next} END { print exists }')
      ${zero-is-ok true}
      ''
    else if check.script-metric != null then ''
        metric=$(${timeoutCmd} ${writeBashScript check.name check.script-metric})
      ''
    else if check.script-retcode != null then ''
        metric=0
        ${timeoutCmd} ${writeBashScript check.name check.script-retcode} || metric=$?
        ${zero-is-ok true}
      ''
    else abort "need at least one implementation for diagnostic ${check.name}";

  # Numerical $metric is mandatory for automated checks.
  # String $out is for humans running `wtf`.
  # Each check may call humanize_* to define $out
  wtfWrapper = check: writeBashScript check.name ''
    if [ ''${WTF_ON_TERMINAL:-0} -eq 1 ]; then
      failed="\e[1;31mFAILED\e[0m"
      ok="\e[0;32mOK\e[0m"
    else
      failed="FAILED"
      ok="OK"
    fi
    out=
    metric=
    trap 'echo -e "--> $out"' EXIT

    humanize_zero_is_ok()
    {
      if [ "$metric" -eq 0 ]; then
        out="$ok"
      else
        out="$metric ($failed)"
      fi
    }

    trap 'out="$failed"' ERR INT TERM
    ${check.shell-impl}
    trap - ERR INT TERM

    metric=$(echo "$metric" | tr -d " \r\n\t")

    if [ -z "$metric" ]; then
      out="$failed"
    fi

    if [ -z "$out" ]; then
      out="$metric ${toString check.timeseries.descriptive-unit}"
    fi

    num=$(echo "$metric" | tr -cd 0-9)
    [ -z "$num" ] || [ "$num" -eq 0 ]
  '';

in
{
  options = {
    shell-impl = mkOption {
      type = types.str;
      internal = true;
      description = ''
        Shell script snippet that should perform the check and set the
        variable <code>metric</code>. Must have a proper timeout mechanism.
      '';
      default = shellImpl config;
    };

    wtf-wrapper = mkOption {
      type = types.path;
      internal = true;
      description = ''
        Wrapper check used by wtf.
      '';

      default = wtfWrapper config;
    };
  };
}
