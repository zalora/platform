{ stdenv, coreutils }:

stdenv.mkDerivation {
  name = "retry";

  # Used by substituteAll.
  inherit coreutils;

  buildCommand = ''
    mkdir -p $out/bin
    substituteAll $script $out/bin/retry
    chmod +x $out/bin/retry
  '';

  script = ./retry;

  meta = with stdenv.lib; {
    description = "Retry failed commands";
    platforms = platforms.all;
    license = licenses.mit;
  };
}
