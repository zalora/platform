{ diagnostics, name ? "wtf" }:
let
  inherit (import <microgram/sdk.nix>) lib sdk pkgs;
  inherit (pkgs) stdenv;
  inherit (lib) types mkOption concatStrings mapAttrsToList mapAttrs;

  eval = lib.evalModules { modules = [ module ]; };
  diags = eval.config.diagnostics;

  module = {
    options = {
      diagnostics = mkOption {
        type = types.attrsOf (types.submodule (import ./api.nix));
        default = diagnostics;
      };

      paths = {
        wtf = mkOption { type = types.path; default = wtf; };
        wtfdb = mkOption { type = types.path; default = wtfdb; };
      };

      test = mkOption {
        type = types.attrsOf types.str;
        default = mapAttrs (_: diag: "${wtf}/bin/wtf ${diag.name}") diags;
      };

      wait = mkOption {
        type = types.attrsOf types.str;
        default = mapAttrs (_: diag: "${wtf}/bin/wtf -w ${diag.name}") diags;
      };
    };
  };

  wtfdb = sdk.writeText "wtfdb.json" (builtins.toJSON diags);

  wtfenv = pkgs.buildEnv {
    name = "${name}-env";
    paths = with sdk; [
      bash coreutils curl findutils gawk gnused inetutils jq ntp
    ];
  };

  wtf = stdenv.mkDerivation {
    inherit name;

    buildCommand = ''
      mkdir -p $out/bin
      substituteAll ${./wtf} $out/bin/wtf
      chmod +x $out/bin/wtf
    '';

    inherit (sdk) bash;

    inherit wtfenv wtfdb;
  };
in eval
