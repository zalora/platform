{ stdenv, fetchurl, bash }:

stdenv.mkDerivation rec {

  name = "newrelic-php5-${version}";
  version = "6.4.0.163";

  src = fetchurl {
    url = "https://download.newrelic.com/php_agent/archive/${version}/${name}-linux.tar.gz";
    sha256 = "1qb77gn96arlcy4rvmr3c7br1y8hhz9n5979crrh3zywmdf0g1kv";
  };

  buildPhase = ":";

  installPhase = ''

    mkdir -p $out/bin

    # patchelf is supposed to do this but it is broken (both the latest release
    # and master at 0ea5aff2edf59da4bcd5287f6268dac75c340959)
    # https://github.com/NixOS/patchelf/issues/66
    orig=$out/bin/newrelic-daemon.x64.orig
    wrapped=$out/bin/newrelic-daemon.x64
    cp daemon/newrelic-daemon.x64 $orig
    {
      echo '#!${bash}/bin/bash'
      echo "exec $(cat $NIX_CC/nix-support/dynamic-linker) $orig \$@"
    } > $wrapped
    chmod +x $wrapped

    mkdir -p $out/extensions
    cp agent/x64/newrelic-20151012.so $out/extensions/newrelic.so
  '';

  meta = with stdenv.lib; {
    description = "PHP agent for New Relic";
    homepage = http://newrelic.com/docs/php/new-relic-for-php;
  };
}
