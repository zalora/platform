#
# Library packages here are grouped by programming language
# and sorted alphabetically within those groups.
#

let
  inherit (import <microgram/sdk.nix>) pkgs lib;
  inherit (pkgs)
    pythonPackages perlPackages haskellPackages
    stdenv_32bit gnome
    stdenv fetchurl newScope;
  inherit (lib) concatMapStringsSep overrideDerivation optionalAttrs;

  fns = rec {
    # exports dependency graph of a derivation as a separate derivation
    exportGraph = drv:
      pkgs.runCommand "${drv.name}-graph" { exportReferencesGraph = [ "graph" drv ]; } ''
        cat graph > $out
      '';

    # Take a Haskell file together with its dependencies, produce a binary.
    # Note: dependencies that are included in GHC itself must not be provided,
    # as that would result in empty elements in GHC_PACKAGE_PATH. FIXME maybe.
    compileHaskell = deps: file:
      let
        canonicalize = "${pkgs.coreutils}/bin/readlink --canonicalize";
        ghc = "$(${canonicalize} ${pkgs.haskellngPackages.ghc}/lib/ghc-*/package.conf.d)";
        depToPath = dep: "$(${canonicalize} ${dep}/nix-support/ghc-*-package.conf.d)";
        paths = concatMapStringsSep ":" depToPath deps;
      in pkgs.runCommand "${baseNameOf (toString file)}-compiled" {} ''
        env GHC_PACKAGE_PATH=${ghc}:${paths} ${pkgs.haskellngPackages.ghc}/bin/ghc -Wall -o "$out" ${file}
      '';

    # Make a statically linked version of a haskell package.
    # Use wisely as it may accidentally kill useful files.
    staticHaskellCallPackage = path: { cabal ? pkgs.haskellPackages.cabal
                                     , ...
                                     }@args:
      let
        orig = pkgs.haskellPackages.callPackage path (args // {
          cabal = cabal.override {
            enableSharedExecutables = false;
            enableSharedLibraries = false;
          };
        });
      in pkgs.runCommand "${orig.name}-static" {} ''
        mkdir -p $out
        (cd ${orig}; find . -type f | grep -vE './(nix-support|share/doc|lib/ghc-)' | xargs -I% cp -r --parents % $out)
      '';

    buildPecl = import <nixpkgs/pkgs/build-support/build-pecl.nix> {
      inherit (pkgs) php stdenv autoreconfHook fetchurl;
    };

    # Until https://github.com/NixOS/nixpkgs/pull/6411 is in

    # Create a single file.
    writeTextFile =
      { name # the name of the derivation
      , text
      , executable ? false # run chmod +x ?
      , destination ? ""   # relative path appended to $out eg "/bin/foo"
      }:
      pkgs.runCommand name
        { inherit text executable;
          passAsFile = [ "text" ];
          # Pointless to do this on a remote machine.
          preferLocalBuild = true;
        }
        ''
          n=$out${destination}
          mkdir -p "$(dirname "$n")"
          if [ -e "$textPath" ]; then
            mv "$textPath" "$n"
          else
            echo -n "$text" > "$n"
          fi
          (test -n "$executable" && chmod +x "$n") || true
        '';

    # Shorthands for `writeTextFile'.
    writeText = name: text: writeTextFile {inherit name text;};
    writeTextDir = name: text: writeTextFile {inherit name text; destination = "/${name}";};
    writeScript = name: text: writeTextFile {inherit name text; executable = true;};
    writeScriptBin = name: text: writeTextFile {inherit name text; executable = true; destination = "/bin/${name}";};
  };

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

  mariadb = pkgs.callPackage ./mariadb {};

  mariadb-galera = pkgs.callPackage ./mariadb-galera {};

  memcached-tool = pkgs.writeScriptBin "memcached-tool" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.perl}/bin/perl ${./memcached/memcached-tool} "$@"
  '';

  mergex = pkgs.callPackage ./mergex {};

  mkebs = pkgs.callPackage ./mkebs {};

  myrapi = fns.staticHaskellCallPackage ./myrapi { inherit servant servantClient; };

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

  nginx = let
    version = "1.9.1";
    fetchFromGitHub = args@{ repo, ... }:
      # XXX: hack https://github.com/openresty/lua-nginx-module/issues/499
      pkgs.fetchFromGitHub (args // optionalAttrs (repo == "lua-nginx-module") {
        rev = "91ff51faf418e5bf283eff0e52c2a8a2348056ab";
        sha256 = "144lj4amjpjgkilbpp4al5bisnkvmb5insn3l28597qcfn887b1d";
      });
  in overrideDerivation (pkgs.nginx.override { ngx_lua = true; rtmp = false; inherit fetchFromGitHub; }) (args: {
    name = "nginx-${version}";
    src = fetchurl {
      url = "http://nginx.org/download/nginx-${version}.tar.gz";
      sha256 = "1b8xikrr19p07n28xnar8p8l0vgm7795lmrb2x7r9h4lwvx5bx89";
    };
    configureFlags = args.configureFlags ++ ["--with-http_stub_status_module"];
  });

  openssl = overrideDerivation pkgs.openssl (_: (rec {
    name = "openssl-1.0.1p";
    src = fetchurl {
      url = "https://www.openssl.org/source/${name}.tar.gz";
      sha256 = "1wdjx4hr3hhhyqx3aw8dmb9907sg4k7wmfpcpdhgph35660fcpmx";
    };
  }));

  percona-toolkit = import ./percona-toolkit { inherit perlPackages fetchurl; };

  php54 = pkgs.callPackage ./php/5.4.nix {};

  pivotal_agent = pkgs.callPackage ./pivotal_agent {};

  put-metric = pkgs.runCommand "${awsEc2.name}-put-metric" {} ''
    mkdir -p $out/bin
    cp ${awsEc2}/bin/put-metric $out/bin
  '';

  rabbitmq = pkgs.callPackage ./rabbitmq { inherit erlang; };

  replicator = fns.staticHaskellCallPackage ./replicator {};

  retry = pkgs.callPackage ./retry {};

  solr = pkgs.callPackage ./solr {};

  sproxy = fns.staticHaskellCallPackage ./sproxy {};

  syslog-ng = pkgs.callPackage ./syslog-ng {};

  thumbor = (import ./thumbor { inherit pkgs newrelic-python statsd; }).thumbor;

  upcast = pkgs.haskellngPackages.callPackage ./upcast {
    inherit vk-posix-pty;
  };

  xd = pkgs.callPackage ./xd {};

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

  #
  # haskell libraries
  #

  awsEc2 = pkgs.haskellPackages.callPackage ./aws-ec2 {};
  servant = pkgs.haskellPackages.callPackage ./servant {};
  servantClient = pkgs.haskellPackages.callPackage ./servant-client { inherit servant servantServer; };
  servantServer = pkgs.haskellPackages.callPackage ./servant-server { inherit servant waiAppStatic; };
  vkAwsRoute53 = pkgs.haskellPackages.callPackage ./vk-aws-route53 {};
  vk-posix-pty = pkgs.haskellPackages.callPackage ./vk-posix-pty {};
  waiAppStatic = pkgs.haskellPackages.callPackage ./wai-app-static {};

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
