#
# Library packages here are grouped by programming language
# and sorted alphabetically within those groups.
#

let
  inherit (import <microgram/sdk.nix>) pkgs lib;
  inherit (import <microgram/lib>) exportSessionVariables;
  inherit (pkgs)
    pythonPackages perlPackages stdenv_32bit gnome stdenv fetchurl newScope;
  inherit (lib)
    concatMapStringsSep overrideDerivation optionalAttrs concatStringsSep;

  haskellPackages = pkgs.haskell.packages.ghc784;

  old_ghc784 = pkgs.callPackage ./haskell-modules {
    ghc = pkgs.haskell.compiler.ghc784;
    packageSetConfig = pkgs.callPackage <nixpkgs/pkgs/development/haskell-modules/configuration-ghc-7.8.x.nix> {};
  };

  fns = rec {

    # exports dependency graph of a derivation as a separate derivation
    exportGraph = drv:
      pkgs.runCommand "${drv.name}-graph" { exportReferencesGraph = [ "graph" drv ]; } ''
        cat graph > $out
      '';

    # Take a Haskell file together with its dependencies, produce a binary.
    compileHaskell = deps: file:
      pkgs.runCommand "${baseNameOf (toString file)}-compiled" {} ''
        ${haskellPackages.ghcWithPackages (self: deps)}/bin/ghc -Wall -o a.out ${file}
        mv a.out $out
      '';

    staticHaskellOverride = staticHaskellOverrideF (_: {});

    staticHaskellOverrideF = f: pkg: pkgs.haskell.lib.overrideCabal pkg (drv: {
      enableSharedExecutables = false;
      enableSharedLibraries = false;
      isLibrary = false;
      doHaddock = false;
      postFixup = "rm -rf $out/lib $out/nix-support $out/share";
      doCheck = false;
    } // (f drv));

    # Make a statically linked version of a haskell package.
    # Use wisely as it may accidentally kill useful files.
    staticHaskellCallPackageWith = ghc: path: args: staticHaskellOverride (ghc.callPackage path args);

    staticHaskellCallPackage = staticHaskellCallPackageWith haskellPackages;

    buildPecl = import <nixpkgs/pkgs/build-support/build-pecl.nix> {
      inherit (pkgs) php stdenv autoreconfHook fetchurl;
    };

    writeBashScriptOverride =
      skipchecks: name: script:
      let
        skipchecks' = skipchecks ++ [
          # pipefail by default doesn't play with SC2143:
          #   https://github.com/koalaman/shellcheck/wiki/SC2143#exceptions
          "SC2143"
          "SC2148"
        ];
        prelude = ''
          #!${pkgs.bash}/bin/bash
          set -e
          set -o pipefail
          # set -u # We are not ready for this yet
          ${exportSessionVariables}
        '';
      in
      pkgs.runCommand name { inherit prelude script; } ''
        echo "$prelude" >> "$out"
        echo "$script" >> "$out"
        chmod +x "$out"
        ${ShellCheck}/bin/shellcheck \
          -e ${concatStringsSep "," skipchecks'} \
          "$out"
      '';

    writeBashScriptBinOverride = skipchecks: name: script: pkgs.runCommand name {} ''
      mkdir -p "$out/bin"
      ln -s "${writeBashScriptOverride skipchecks name script}" "$out/bin/${name}"
    '';

    writeBashScript = writeBashScriptOverride [];

    writeBashScriptBin = writeBashScriptBinOverride [];
  };

  ShellCheck = fns.staticHaskellOverrideF (_: {
    preConfigure = "sed -i -e /ShellCheck,/d ShellCheck.cabal";
  }) haskellPackages.ShellCheck;

in rec {
  inherit fns; # export functions as well

  angel = fns.staticHaskellCallPackage ./angel {};

  bridge-utils = pkgs.bridge_utils;

  couchbase = pkgs.callPackage ./couchbase {};

  curl-loader = pkgs.callPackage ./curl-loader {};

  damemtop = pkgs.writeScriptBin "damemtop" ''
    #!${pkgs.bash}/bin/bash
    exec env PERL5LIB=${lib.makePerlPath (with perlPackages; [ AnyEvent GetoptLong TermReadKey YAML ])} \
      ${pkgs.perl}/bin/perl ${./memcached/damemtop} "$@"
  '';

  docker = pkgs.callPackage ./docker { inherit go bridge-utils; };

  elasticsearch-cloud-aws = pkgs.stdenv.mkDerivation rec {
    name = "elasticsearch-cloud-aws-${version}";
    version = "2.4.1";
    src = fetchurl {
      url = "http://search.maven.org/remotecontent?filepath=org/elasticsearch/elasticsearch-cloud-aws/${version}/${name}.zip";
      sha256 = "1nvfvx92q9p0yny45jjfwdvbpn0qh384s6714wmm7qivbylb8f03";
    };
    phases = [ "installPhase" ];
    buildInputs = [ pkgs.unzip ];
    installPhase = ''
      mkdir -p $out/plugins/cloud-aws
      unzip $src -d $out/plugins/cloud-aws
    '';
  };

  erlang = pkgs.callPackage ./erlang {};

  exim = pkgs.callPackage ./exim {};

  galera-wsrep = pkgs.callPackage ./galera-wsrep {
    boost = pkgs.boost.override { enableStatic = true; };
  };

  gdb-quiet = stdenv.mkDerivation {
    name = "gdb-quiet";
    unpackPhase = ''
      true
    '';
    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cat > $out/bin/gdb << EOF
      #!/bin/sh
      exec ${pkgs.gdb}/bin/gdb -q -ex 'set auto-load safe-path /' "\$@"
      EOF
      chmod +x $out/bin/gdb

      runHook postInstall
    '';
  };

  get-user-data = pkgs.writeScriptBin "get-user-data" ''
    #! /bin/sh
    exec ${pkgs.wget}/bin/wget \
      --retry-connrefused \
      -q -O - http://169.254.169.254/latest/user-data
  '';

  go = pkgs.callPackage ./go/1.4.nix {};

  graphviz = pkgs.callPackage ./graphviz {};

  heavy-sync = with pythonPackages; pkgs.callPackage ./heavy-sync {
    inherit boto;
    inherit gcs-oauth2-boto-plugin;
    inherit sqlite3;
  };

  imagemagick = pkgs.callPackage ./ImageMagick {
    libX11 = null;
    ghostscript = null;
    tetex = null;
    librsvg = null;
  };

  incron = pkgs.callPackage ./incron {};

  jenkins = pkgs.callPackage ./jenkins {};

  kibana4 = pkgs.srcOnly {
    name = "kibana-4.0.0";
    src = fetchurl {
      url = https://download.elasticsearch.org/kibana/kibana/kibana-4.0.0-linux-x64.tar.gz;
      sha256 = "0bng4mmmhc2lhfk9vxnbgs4d7hiki5dlzrggzvd96dw0a8gy47cg";
    };
  };

  # microgram default linux
#  linux = pkgs.callPackage ./linux-kernel/ubuntu/ubuntu-overrides.nix {
#    kernel = linux_3_19;
#  };

  linux = linux_3_19;

  linux_3_19 = pkgs.makeOverridable (import ./linux-kernel/3.19.nix) {
    inherit (pkgs) fetchurl stdenv perl buildLinux;
  };

  linuxPackages =
    let callPackage = newScope linuxPackages; in
    pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor linux linuxPackages) // rec {
      sysdig = callPackage ./sysdig {};

      virtualbox = callPackage ./virtualbox {
        stdenv = stdenv_32bit;
        inherit (gnome) libIDL;
      };

      virtualboxGuestAdditions = stdenv.lib.overrideDerivation (callPackage ./virtualbox/guest-additions { inherit virtualbox; }) (args: {
        src = fetchurl {
          url = "http://download.virtualbox.org/virtualbox/${virtualbox.version}/VBoxGuestAdditions_${virtualbox.version}.iso";
          sha256 = "c5e46533a6ff8df177ed5c9098624f6cec46ca392bab16de2017195580088670";
        };

      });
    };

  lua-json = pkgs.fetchzip {
    url = "http://files.luaforge.net/releases/json/json/0.9.50/json4lua-0.9.50.zip";
    sha256 = "1qmrq6gsirjzkmh2yd8h43vpi02c0na90i3i28z57a7nsg12185k";
  };

  mariadb = pkgs.callPackage ./mariadb/multilib.nix {};

  mariadb-galera = pkgs.callPackage ./mariadb-galera {};

  memcached-tool = pkgs.writeScriptBin "memcached-tool" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.perl}/bin/perl ${./memcached/memcached-tool} "$@"
  '';

  mergex = pkgs.callPackage ./mergex {};

  mkebs = pkgs.callPackage ./mkebs {};

  myrapi = fns.staticHaskellCallPackage ./myrapi { inherit servant servant-client; };

  mysql55 = pkgs.callPackage ./mysql/5.5.x.nix {};

  newrelic-java = pkgs.fetchurl {
    url = "https://download.newrelic.com/newrelic/java-agent/newrelic-agent/3.12.0/newrelic-agent-3.12.0.jar";
    sha256 = "1ssr7si7cbd1wg39lkgsi0nxnh5k0xjsbcjsnn33jm2khx7q0cji";
  };

  newrelic-memcached-plugin = pkgs.srcOnly rec {
    name = "newrelic_memcached_plugin-2.0.1";
    src = pkgs.fetchurl {
      url = "https://github.com/newrelic-platform/newrelic_memcached_java_plugin/raw/master/dist/${name}.tar.gz";
      sha256 = "16kyb42as8plabbfv8v3vhp6hjzxw1ry80ghf2zbkg0v4s1r5m6w";
    };
  };

  newrelic-mysql-plugin = pkgs.srcOnly rec {
    name = "newrelic_mysql_plugin-2.0.0";
    src = pkgs.fetchurl {
      url = "https://github.com/newrelic-platform/newrelic_mysql_java_plugin/raw/master/dist/${name}.tar.gz";
      sha256 = "158afq1q11bwjzcrsm860n8vj1xzdasql86b9qpwyhs4czjy0grd";
    };
  };

  newrelic-php = pkgs.callPackage ./newrelic-php {};

  newrelic-plugin-agent = with pythonPackages; pkgs.callPackage ./newrelic-plugin-agent {
    inherit helper requests2;
  };

  newrelic-sysmond = pkgs.callPackage ./newrelic-sysmond {};

  nix = pkgs.callPackage ./nix {};

  # Until we can get to https://github.com/NixOS/nixpkgs/pull/9997
  nginx = pkgs.callPackage ./nginx/unstable.nix {
    ngx_lua = true;
    withStream = true;
  };

  openssl = overrideDerivation pkgs.openssl (_: (rec {
    name = "openssl-1.0.1p";
    src = fetchurl {
      url = "https://www.openssl.org/source/${name}.tar.gz";
      sha256 = "1wdjx4hr3hhhyqx3aw8dmb9907sg4k7wmfpcpdhgph35660fcpmx";
    };
  }));

  percona-toolkit = import ./percona-toolkit { inherit perlPackages fetchurl; };

  php54 = pkgs.callPackage ./php/5.4.nix {};
  php53 = pkgs.callPackage ./php/5.3.nix {};

  pivotal_agent = pkgs.callPackage ./pivotal_agent {};

  put-metric = let
    aws-ec2 = fns.staticHaskellCallPackage ./aws-ec2 {};
  in pkgs.runCommand "${aws-ec2.name}-put-metric" {} ''
    mkdir -p $out/bin
    cp ${aws-ec2}/bin/put-metric $out/bin
  '';

  rabbitmq = pkgs.callPackage ./rabbitmq { inherit erlang; };

  replicator = fns.staticHaskellCallPackage ./replicator {};

  retry = pkgs.callPackage ./retry {};

  inherit ShellCheck;

  sproxy = (fns.staticHaskellCallPackageWith old_ghc784) ./sproxy {};

  syslog-ng = pkgs.callPackage ./syslog-ng {};

  thumbor = (import ./thumbor { inherit pkgs newrelic-python statsd tornado; }).thumbor;

  unicron = fns.staticHaskellCallPackage ./unicron {};

  upcast = pkgs.haskell.lib.overrideCabal (fns.staticHaskellCallPackage ./upcast {
    inherit amazonka amazonka-core amazonka-ec2 amazonka-elb amazonka-route53;
  }) (drv: {
    postFixup = "rm -rf $out/lib $out/nix-support";
  });

  xd = pkgs.callPackage ./xd {};

  ybc = pkgs.callPackage ./ybc {};

  #
  # python libraries
  #

  helper = pythonPackages.buildPythonPackage rec {
    name = "helper-2.4.1";

    propagatedBuildInputs = with pythonPackages; [ pyyaml ];
    buildInputs = with pythonPackages; [ mock ];

    src = fetchurl {
      url = "https://pypi.python.org/packages/source/h/helper/${name}.tar.gz";
      md5 = "e7146c95bbd96a12df8d737a16dca3a7";
    };

    meta = with stdenv.lib; {
      description = "Helper";
      homepage = https://helper.readthedocs.org;
      license = licenses.bsd3;
    };
  };

  newrelic-python = import ./newrelic-python { inherit pkgs; };

  statsd = pythonPackages.buildPythonPackage rec {
    name = "statsd-3.0.1";

    src = fetchurl {
      url = "https://pypi.python.org/packages/source/s/statsd/${name}.tar.gz";
      md5 = "af256148584ed4daa66f50c30b5c1f95";
    };

    doCheck = false;

    propagatedBuildInputs = with pythonPackages; [];

    meta = with stdenv.lib; {
      homepage = https://github.com/jsocol/pystatsd;
      license = licenses.mit;
    };
  };

  tornado = pythonPackages.buildPythonPackage rec {
    name = "tornado-3.2";

    propagatedBuildInputs = with pythonPackages; [ backports_ssl_match_hostname_3_4_0_2 ];

    src = pkgs.fetchurl {
      url = "https://pypi.python.org/packages/source/t/tornado/${name}.tar.gz";
      md5 = "bd83cee5f1a5c5e139e87996d00b251b";
    };

    doCheck = false;
  };

  #
  # haskell libraries
  #

  amazonka = haskellPackages.callPackage ./amazonka { inherit amazonka-core; };
  amazonka-core = haskellPackages.callPackage ./amazonka-core {};
  amazonka-ec2 = haskellPackages.callPackage ./amazonka-ec2 { inherit amazonka-core; };
  amazonka-elb = haskellPackages.callPackage ./amazonka-elb { inherit amazonka-core; };
  amazonka-route53 = haskellPackages.callPackage ./amazonka-route53 { inherit amazonka-core; };

  # servant 0.2.x
  servant = haskellPackages.callPackage ./servant {};
  servant-client = haskellPackages.callPackage ./servant-client { inherit servant; };
  servant-server = haskellPackages.callPackage ./servant-server { inherit servant; };

  #
  # clojure/java libraries
  #

  clj-json = fetchurl {
    url = https://clojars.org/repo/clj-json/clj-json/0.5.3/clj-json-0.5.3.jar;
    sha256 = "1rwmmsvyvpqadv94zxzgn07qj0nf5jh0nhd218mk94y23l5mksxs";
  };

  elastisch = fetchurl {
    url = https://clojars.org/repo/clojurewerkz/elastisch/1.4.0/elastisch-1.4.0.jar;
    sha256 = "17nwcqh9wqvw0avi4lqgdma8qxfylif8ngv6sjdp84c8dn2i9rpf";
  };

  jackson-core-asl = fetchurl {
    url = "http://search.maven.org/remotecontent?filepath=org/codehaus/jackson/jackson-core-asl/1.9.9/jackson-core-asl-1.9.9.jar";
    sha256 = "15wq8g2qhix93f2gq6006fwpi75diqkx6hkcbdfbv0vw5y7ibi2z";
  };

  kiries = pkgs.fetchgit {
    url = https://github.com/threatgrid/kiries.git;
    rev = "dc9a6c76577f8dbfea6acdb6e43d9da13472a9a7";
    sha256 = "bf1b3a24e4c8e947c431e4a53d9a722383344e6c669eb5f86beb24539a25e880";
  };


  #
  # php libraries
  #

  imagick = fns.buildPecl {
    name = "imagick-3.1.2";
    sha256 = "14vclf2pqcgf3w8nzqbdw0b9v30q898344c84jdbw2sa62n6k1sj";
    buildInputs = [ pkgs.pkgconfig ];
    configureFlags = [
      "--with-imagick=${imagemagick}"
    ];

    NIX_CFLAGS_COMPILE = "-I${imagemagick}/include/ImageMagick-6";
  };
}
