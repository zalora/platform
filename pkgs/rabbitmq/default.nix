{ pkgs, stdenv }:

stdenv.mkDerivation rec {
  name = "rabbitmq-server-${version}";

  version = "3.6.3";

  src = pkgs.fetchurl {
    url = "http://www.rabbitmq.com/releases/rabbitmq-server/v${version}/${name}.tar.xz";
    sha256 = "13v48wm0n3rrga7sid5i79ksn2rd30md45jzjz9z3pfz3jmj4fq5";
  };

  buildInputs = [
    pkgs.docbook_xml_dtd_45
    pkgs.docbook_xsl
    pkgs.erlang
    pkgs.libxml2
    pkgs.libxslt
    pkgs.python
    pkgs.rsync
    pkgs.unzip
    pkgs.xmlto
    pkgs.zip
  ];

  makeFlags = "RMQ_ERLAPP_DIR=$(out)";

  postInstall = ''
    echo 'PATH=${pkgs.erlang}/bin''${PATH:+:$PATH}' >> $out/sbin/rabbitmq-env
  '';
}
