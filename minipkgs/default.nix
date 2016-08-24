let
  sdkroot = import <microgram/sdk.nix>;
  bigpkgs = sdkroot.pkgs;
  inherit (bigpkgs) system;
  inherit (sdkroot) lib nixpkgs-config;
in
rec {
  # Yes, i'm using a binary compiler randomly discovered on the internets.
  # Latest musl is 1.1.11 and must be used ASAP.
  cross-musl-archive = bigpkgs.fetchurl {
    url = https://e82b27f594c813a5a4ea5b07b06f16c3777c3b8c.googledrive.com/host/0BwnS5DMB0YQ6bDhPZkpOYVFhbk0/musl-1.1.6/crossx86-x86_64-linux-musl-1.1.6.tar.xz;
    sha256 = "0q42hhn4clipgl5jrg3yvwphqv78fmf8rid68ldkgm5cb9ws1vb8";
  };

  cross-musl = bigpkgs.srcOnly {
    name = "cross-musl";
    src = cross-musl-archive;
  };

  cc-wrapper = bigpkgs.runCommand "musl-cross-cc-wrapper" {
    preferLocalBuild = true;
    libc = "${cross-musl}/x86_64-linux-musl";
    nativeTools = false;
  } ''
    mkdir -p $out/{bin,nix-support}

    wrap() {
      local dst="$1"
      local wrapper="$2"
      export prog="$3"
      substituteAll "$wrapper" "$out/bin/$dst"
      chmod +x "$out/bin/$dst"
    }

    prefix=x86_64-linux-musl
    for binary in ${cross-musl}/bin/$prefix-*; do # */
      bname=''${binary##*/$prefix-}
      ln -svf $binary $out/bin/$bname
    done

    echo "-B$libc/lib/ -idirafter $libc/include -idirafter $libc/lib/gcc/*/*/include-fixed" > $out/nix-support/libc-cflags

    echo "-L$libc/lib" > $out/nix-support/libc-ldflags
    echo "-L$libc/lib" > $out/nix-support/cc-ldflags
    echo "-B$libc/lib" > $out/nix-support/cc-cflags

    dynamicLinker="$libc/lib/libc.so"
    echo "$dynamic-linker" > $out/nix-support/dynamic-linker
    echo "-dynamic-linker" $dynamicLinker > $out/nix-support/libc-ldflags-before

    cd $out/bin
    rm -f gcc cc cpp ld ld.bfd
    wrap gcc ${<nixpkgs/pkgs/build-support/cc-wrapper/cc-wrapper.sh>} ${cross-musl}/bin/$prefix-gcc
    ln -s gcc $out/bin/cc
    wrap cpp ${<nixpkgs/pkgs/build-support/cc-wrapper/cc-wrapper.sh>} ${cross-musl}/bin/$prefix-gcc
    export real_cc=gcc
    export real_cxx=g++
    wrap ld ${<nixpkgs/pkgs/build-support/cc-wrapper/ld-wrapper.sh>} ${cross-musl}/bin/$prefix-ld
    wrap ld.bfd ${<nixpkgs/pkgs/build-support/cc-wrapper/ld-wrapper.sh>} ${cross-musl}/bin/$prefix-ld.bfd

    substituteAll ${<nixpkgs/pkgs/build-support/cc-wrapper/setup-hook.sh>} $out/nix-support/setup-hook.tmp
    cat $out/nix-support/setup-hook.tmp >> $out/nix-support/setup-hook
    rm $out/nix-support/setup-hook.tmp

    substituteAll ${<nixpkgs/pkgs/build-support/cc-wrapper/add-flags>} $out/nix-support/add-flags.sh
    cp -p ${<nixpkgs/pkgs/build-support/cc-wrapper/utils.sh>} $out/nix-support/utils.sh
  '';

  # TODO: probably want to replace bootstrapTools with something more thin

  inherit (import <nixpkgs/pkgs/stdenv/linux> { inherit system; }) bootstrapTools stage0;

  stdenv = import <nixpkgs/pkgs/stdenv/generic> {
    inherit system;
    config = {};
    extraBuildInputs = [];
    name = "stdenv-musl";
    preHook = ''
      # Don't patch #!/interpreter because it leads to retained
      # dependencies on the bootstrapTools in the final stdenv.
      dontPatchShebangs=1
      export NIX_ENFORCE_PURITY=1
      #${if system == "x86_64-linux" then "NIX_LIB64_IN_SELF_RPATH=1" else ""}
    '';
    shell = "${bootstrapTools}/bin/sh";
    initialPath = [bootstrapTools];
    fetchurlBoot = import <nixpkgs/pkgs/build-support/fetchurl> {
      stdenv = stage0.stdenv;
      curl = bootstrapTools;
    };

    cc = cc-wrapper;

    extraAttrs = {
      platform = null;
    };
    overrides = pkgs: { fetchurl = stdenv.fetchurlBoot; };
  };

  minipkgs = import <nixpkgs> {
    config = nixpkgs-config // {
      packageOverrides = pkgs: (nixpkgs-config.packageOverrides pkgs) // {
        gawk = lib.overrideDerivation pkgs.gawk (drv: {
          doCheck = false;  # wants `more', not mentions in buildInputs,
                            # perhaps expected to come with stdenv
        });

        gnum4 = lib.overrideDerivation pkgs.gnum4 (drv: {
          doCheck = false; # localeconv crashes, fixed in newer musl
        });

        gpm = null; # fails to build, couldn't care less

        openssl = lib.overrideDerivation pkgs.openssl (drv: {
          postInstall = ''
            # do not remove static libraries!

            # remove dependency on Perl at runtime
            rm -r $out/etc/ssl/misc $out/bin/c_rehash
          '';
        });

        ncurses = lib.overrideDerivation pkgs.ncurses (drv: {
          preFixup = ''
            # do not remove static libraries!
          '';
        });
      };
      replaceStdenv = {pkgs}: stdenv;
    };
  };

  erlang = minipkgs.callPackage ../pkgs/erlang {};
}
