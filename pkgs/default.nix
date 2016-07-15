#
# Library packages here are grouped by programming language
# and sorted alphabetically within those groups.
#

let
  inherit (import <microgram/sdk.nix>) pkgs lib;
  inherit (pkgs)
    pythonPackages perlPackages stdenv_32bit gnome stdenv fetchurl newScope;
  inherit (lib)
    concatMapStringsSep overrideDerivation optionalAttrs concatStringsSep;

  haskellPackages = pkgs.haskellPackages;

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

    writeBashScriptOverride = skipchecks: name: script:
      let
        base = [
          "SC1091"  # file inputs, not ready for this yet
          "SC1090"  # file inputs with variables
        ];
        exc = concatMapStringsSep " " (e: "-e ${e}") (base ++ skipchecks);
      in pkgs.runCommand name { inherit script; } ''
        echo '#!${pkgs.bash}/bin/bash' > "$out"
        echo "$script" >> "$out"
        chmod +x "$out"
        ${ShellCheck}/bin/shellcheck ${exc} "$out"
      '';

    writeBashScriptBinOverride = skipchecks: name: script:
      pkgs.runCommand name {} ''
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

  ares = fns.staticHaskellCallPackage ./ares {};

  bundler_HEAD = import ./bundler/bundler-head.nix {
    inherit (pkgs) buildRubyGem coreutils fetchgit;
  };

  couchbase = pkgs.callPackage ./couchbase {};

  curl-loader = pkgs.callPackage ./curl-loader {};

  damemtop = pkgs.writeScriptBin "damemtop" ''
    #!${pkgs.bash}/bin/bash
    exec env PERL5LIB=${lib.makePerlPath (with perlPackages; [ AnyEvent GetoptLong TermReadKey YAML ])} \
      ${pkgs.perl}/bin/perl ${./memcached/damemtop} "$@"
  '';

  dynomite = pkgs.callPackage ./dynomite {};

  filebeat = pkgs.callPackage ./filebeat {
    go = pkgs.go_1_5;
  };

  flame-graph = pkgs.callPackage ./flame-graph { inherit (pkgs) perl; };

  elasticsearch-cloud-aws = pkgs.stdenv.mkDerivation rec {
    name = "elasticsearch-cloud-aws-${version}";
    version = "2.7.1";
    src = fetchurl {
      url = "http://search.maven.org/remotecontent?filepath=org/elasticsearch/elasticsearch-cloud-aws/${version}/${name}.zip";
      sha256 = "1lppzd9kzybfr6r7b01ggcdx09ccv4ml8bqh5wh88yhh473yrg8s";
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

  graphviz = pkgs.callPackage ./graphviz {};

  heavy-sync = with pythonPackages; pkgs.callPackage ./heavy-sync {
    inherit boto;
    inherit gcs-oauth2-boto-plugin;
    inherit sqlite3;
  };

  curator = pkgs.callPackage ./curator {
    inherit (pythonPackages) click elasticsearch urllib3 nosexcover mock;
  };

  imagemagick = pkgs.callPackage ./ImageMagick {
    libX11 = null;
    ghostscript = null;
    tetex = null;
    librsvg = null;
  };

  incron = pkgs.callPackage ./incron {};

  jenkins = pkgs.callPackage ./jenkins {};

  jmaps = pkgs.callPackage ./jmaps { inherit perf-map-agent; inherit (pkgs) openjdk; };

  kibana4 = pkgs.srcOnly {
    name = "kibana-4.1.2";
    src = fetchurl {
      url = https://download.elasticsearch.org/kibana/kibana/kibana-4.1.2-linux-x64.tar.gz;
      sha256 = "031ppiwv35bk86dkiicv2g59pk3c67khj3vmlqb11xvymkvi6qjz";
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

  logstash-all-plugins = pkgs.callPackage ./logstash-all-plugins {};

  lua-json = pkgs.fetchzip {
    url = "http://files.luaforge.net/releases/json/json/0.9.50/json4lua-0.9.50.zip";
    sha256 = "1qmrq6gsirjzkmh2yd8h43vpi02c0na90i3i28z57a7nsg12185k";
  };

  mariadb = pkgs.callPackage ./mariadb/default.nix {};

  mariadb-galera = pkgs.callPackage ./mariadb-galera {};

  memcached-tool = pkgs.writeScriptBin "memcached-tool" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.perl}/bin/perl ${./memcached/memcached-tool} "$@"
  '';

  mergex = pkgs.callPackage ./mergex {};

  mkebs = pkgs.callPackage ./mkebs {};

  myrapi = fns.staticHaskellCallPackage ./myrapi {};

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

  nq = pkgs.callPackage ./nq {};

  openssl = overrideDerivation pkgs.openssl (_: (rec {
    name = "openssl-1.0.1p";
    src = fetchurl {
      url = "https://www.openssl.org/source/${name}.tar.gz";
      sha256 = "1wdjx4hr3hhhyqx3aw8dmb9907sg4k7wmfpcpdhgph35660fcpmx";
    };
  }));

  packer = pkgs.callPackage ./packer {};

  percona-toolkit = import ./percona-toolkit { inherit perlPackages fetchurl; };

  perf-map-agent = import ./perf-map-agent
    { inherit (pkgs) stdenv fetchgit cmake openjdk; };

  inherit (pkgs.callPackage ./php {}) php56 php70;

  pivotal_agent = pkgs.callPackage ./pivotal_agent {};

  rabbitmq = pkgs.callPackage ./rabbitmq {
    pkgs = pkgs // {
      inherit erlang;
    };
  };

  rabbitmq-clusterer = pkgs.callPackage ./rabbitmq-clusterer {};

  replicator = fns.staticHaskellCallPackage ./replicator {};

  retry = pkgs.callPackage ./retry {};

  rootfs-busybox = pkgs.fetchurl {
    url = https://github.com/proger/docker-busybox/raw/master/rootfs.tar;
    sha256 = "067m7jdz71v703azwka1yj6kbbcm3h2sfcwg92clrvgnpgp7fvy3";
  };

  runc = pkgs.callPackage ./runc {};

  inherit ShellCheck;

  # This and its dependencies appear somewhere between 15.09 and 16.03
  simp_le =
  let
    pythonPackagesPlus1 = pkgs.pythonPackages // {
      buildPythonApplication = args: pkgs.buildPythonPackage ({namePrefix="";} // args );
    };
    pythonPackagesPlus2 = pythonPackagesPlus1 // pkgs.callPackage ./simp_le/python-packages.nix {
      pkgs = pkgs // {
        letsencrypt = pkgs.callPackage ./letsencrypt {
          pythonPackages = pythonPackagesPlus1;
        };
      };
    };
  in pkgs.callPackage ./simp_le {
    pythonPackages = pythonPackagesPlus2;
  };

  sproxy = fns.staticHaskellCallPackage ./sproxy {};

  stack = let
     version = "1.0.0";
     tarball = pkgs.fetchurl {
       url = "https://github.com/commercialhaskell/stack/releases/download/v${version}/stack-${version}-linux-x86_64.tar.gz";
       sha256 = "1ckqbyphvhb76jvrfb263x9lpvwm0b4wqknjda2kvcmhqfxafswv";
     };
     stack1 = pkgs.srcOnly {
       name = "stack-${version}-bin1";
       src = tarball;
     };
     inherit (pkgs) stdenv zlib gmp ncurses;

     stack2 = pkgs.runCommand "stack-${version}-bin2" {} ''
       mkdir -p $out/bin
       cp ${stack1}/stack $out/bin
       patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/stack
       patchelf --set-rpath ${stdenv.cc.cc}/lib64:${lib.makeSearchPath "lib" [ stdenv.cc.cc zlib gmp ncurses]} $out/bin/stack
     '';

     rdeps = [ zlib gmp ];

     stack3 = pkgs.writeScriptBin "stack" ''
       #!${stdenv.shell}
       exec ${stack2}/bin/stack \
         ${lib.concatStringsSep " " (map (x: "--extra-lib-dirs ${x}/lib --extra-include-dirs ${x}/include") rdeps)} \
         "$@"
     '';
   in stack3;

  syslog-ng = pkgs.callPackage ./syslog-ng {};

  terraform = pkgs.callPackage ./terraform {};

  thumbor = (import ./thumbor { inherit pkgs newrelic-python statsd tornado; }).thumbor;

  to-json-array = fns.staticHaskellCallPackage ./to-json-array {};

  twemproxy = pkgs.callPackage ./twemproxy {};

  unicron = fns.staticHaskellCallPackage ./unicron {};

  upcast = lib.overrideDerivation (fns.staticHaskellCallPackage ./upcast {
    inherit (amazonka_1_1_0) amazonka amazonka-core amazonka-ec2 amazonka-elb amazonka-route53;
  }) (drv: {
    postFixup = "rm -rf $out/lib $out/nix-support";
  });

  upcast-ng = lib.overrideDerivation (fns.staticHaskellCallPackage ./upcast/ng.nix {
    inherit amazonka amazonka-cloudwatch
            amazonka-core amazonka-ec2 amazonka-elb amazonka-route53;
  }) (drv: {
    postFixup = ''
      rm -rf $out/lib $out/nix-support
      mv $out/bin/upcast $out/bin/upcast-ng
    '';
  });

  vault = pkgs.callPackage ./vault {};

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

  # modern stuff
  amazonka = haskellPackages.callPackage ./amazonka
    { inherit amazonka-core; retry = haskell-retry; };
  amazonka-cloudwatch = haskellPackages.callPackage ./amazonka-cloudwatch
    { inherit amazonka-core amazonka-test; };
  amazonka-core = haskellPackages.callPackage ./amazonka-core {};
  amazonka-ec2 = haskellPackages.callPackage ./amazonka-ec2
    { inherit amazonka-core amazonka-test; };
  amazonka-elb = haskellPackages.callPackage ./amazonka-elb
    { inherit amazonka-core amazonka-test; };
  amazonka-route53 = haskellPackages.callPackage ./amazonka-route53
    { inherit amazonka-core amazonka-test; };
  amazonka-test = haskellPackages.callPackage ./amazonka-test
    { inherit amazonka-core; };

  # compat
  amazonka_1_1_0 = rec {
    amazonka = haskellPackages.callPackage ./amazonka/1.1.0.nix
      { inherit amazonka-core; };
    amazonka-core = haskellPackages.callPackage ./amazonka-core/1.1.0.nix {};
    amazonka-ec2 = haskellPackages.callPackage ./amazonka-ec2/1.1.0.nix
      { inherit amazonka-core; };
    amazonka-elb = haskellPackages.callPackage ./amazonka-elb/1.1.0.nix
      { inherit amazonka-core; };
    amazonka-route53 = haskellPackages.callPackage ./amazonka-route53/1.1.0.nix
      { inherit amazonka-core; };
  };

  # Ugly collision with tv's retry, maybe we should namespace
  # Haskell/cabal things into a subdirectory? If not going the
  # stack/ECR route..
  haskell-retry = haskellPackages.callPackage ./haskell-retry {};

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

  # Adapted from
  # https://github.com/NixOS/nixpkgs/blob/bac26e08dbb6622c39bba13047c54e80282d031d/pkgs/top-level/php-packages.nix#L35-L40
  imagick = fns.buildPecl {
    name = "imagick-3.4.1";
    sha256 = "1qa9jih2x0n3g9kaax0q8bcdqdmnpwjr5p319n14b88akvbgnad7";
    configureFlags = "--with-imagick=${pkgs.imagemagick}";
    buildInputs = [ pkgs.pkgconfig ];
  };

  # Adapted from
  # https://github.com/NixOS/nixpkgs/blob/bac26e08dbb6622c39bba13047c54e80282d031d/pkgs/top-level/php-packages.nix#L66-L82
  # Not released yet
  memcached = fns.buildPecl rec {
    name = "memcached-php7";

    src = pkgs.fetchgit {
      url = "https://github.com/php-memcached-dev/php-memcached";
      rev = "e573a6e8fc815f12153d2afd561fc84f74811e2f";
      sha256 = "13y5p6mrm4k9f6gn3iszfdjdn136myd00vbvwvngjbpg0jpgvb7p";
    };

    configureFlags = [
      "--enable-memcached-json=yes"
      "--with-zlib-dir=${pkgs.zlib}"
      "--with-libmemcached-dir=${pkgs.libmemcached}"
    ];

    buildInputs = with pkgs; [ pkgconfig cyrus_sasl ];
  };

  # Adapted from
  # https://github.com/NixOS/nixpkgs/blob/bac26e08dbb6622c39bba13047c54e80282d031d/pkgs/top-level/php-packages.nix#L95-L102
  xdebug = fns.buildPecl {
    name = "xdebug-2.4.0";
    sha256 = "01gfbvdwy4is31q3d2n4i8lzs6h40xim9angwws3arfi14kwnk9w";
    doCheck = true;
    checkTarget = "test";
  };

  # Adapted from
  # https://github.com/NixOS/nixpkgs/blob/bac26e08dbb6622c39bba13047c54e80282d031d/pkgs/top-level/php-packages.nix#L125-L140
  zmq = fns.buildPecl rec {
    name = "zmq-1.1.3";
    sha256 = "1kj487vllqj9720vlhfsmv32hs2dy2agp6176mav6ldx31c3g4n4";
    configureFlags = [
      "--with-zmq=${pkgs.zeromq2}"
    ];
    buildInputs = [ pkgs.pkgconfig ];
  };
  
  lz4 = fns.buildPecl rec {
     name = "lz4";
     src = pkgs.fetchFromGitHub {
       owner = "kjdev";
       repo = "php-ext-lz4";
       rev = "4a718448323c0c4a18c46ee74bf9d13bde5a6543";
       sha256 = "1j2fgg9pfy3gz14i8fr5wbfyrspibhqnxkx9fdfg9412cbs9whzl";
     };
     buildInputs = with pkgs; [ pkgconfig ];
   };
}
