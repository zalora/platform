{ stdenv, fetchurl, perl, gnum4, ncurses, openssl, gnused, gawk, makeWrapper }:

let
 inherit (stdenv.lib) platforms optional;
in
stdenv.mkDerivation rec {
  name = "erlang-" + version;
  version = "18.0";

  src = fetchurl {
    url = "http://www.erlang.org/download/otp_src_${version}.tar.gz";
    sha256 = "1ahi865ii3iqzd00yyn3nrxjb9qa2by9d7ixssvqw8ag9firvdm0";
  };

  buildInputs = [ perl gnum4 ncurses openssl makeWrapper ];

  preConfigure = ''
    export HOME=$PWD/../
    export CPPFLAGS="-D_BSD_SOURCE $CPPFLAGS"
    export LIBS="$LIBS -lssl -lcrypto"
    sed -e s@/bin/pwd@pwd@g -i otp_build
    sed -i "s@/bin/rm@rm@" lib/odbc/configure erts/configure
    sed -i 's@-o $(BINDIR)/$(EMULATOR_EXECUTABLE)@-static -o $(BINDIR)/$(EMULATOR_EXECUTABLE)@' erts/emulator/Makefile.in
  '';

  configureFlags = [
    "--with-ssl=${openssl}"
    "--disable-shared"
    "--disable-hipe"
    "--disable-megaco-flex-scanner-lineno"
    "--disable-megaco-reentrant-flex-scanner"
    "--disable-dynamic-ssl-lib"
    "--enable-builtin-zlib"
    "--disable-native-libs"
    "--enable-static-nifs"
    "--enable-static-drivers"
    "--disable-silent-rules" # verbose build output
  ] ++ optional stdenv.isDarwin "--enable-darwin-64bit";

  patches = [
    ./hipe_x86_signal-fix.patch
    ./remove-private-unit32.patch
    ./replace_glibc_check.patch
  ];

  postInstall = ''
    ln -s $out/lib/erlang/lib/erl_interface*/bin/erl_call $out/bin/erl_call
  '';

  # Some erlang bin/ scripts run sed and awk
  postFixup = ''
    wrapProgram $out/lib/erlang/bin/erl --prefix PATH ":" "${gnused}/bin/"
    wrapProgram $out/lib/erlang/bin/start_erl --prefix PATH ":" "${gnused}/bin/:${gawk}/bin"
  '';

  meta = {
    homepage = "http://www.erlang.org/";
    description = "Programming language used for massively scalable soft real-time systems";

    longDescription = ''
      Erlang is a programming language used to build massively scalable
      soft real-time systems with requirements on high availability.
      Some of its uses are in telecoms, banking, e-commerce, computer
      telephony and instant messaging. Erlang's runtime system has
      built-in support for concurrency, distribution and fault
      tolerance.
    '';

    platforms = platforms.unix;
  };
}
