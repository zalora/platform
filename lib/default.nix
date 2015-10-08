let
  inherit (import <microgram/sdk.nix>) lib sdk;
  inherit (lib) mapAttrsToList concatStringsSep makeSearchPath;
in rec {

  makeBinPath = makeSearchPath "bin";

  exportSessionVariables = mapcats (k: v: "[[ -f ${v} ]] && export ${k}=${v}") {

    TZDIR = "${sdk.tzdata}/share/zoneinfo";

    # SSL stuff. The last two seem to be deprecated. See
    # https://github.com/NixOS/nixpkgs/blob/release-14.12/nixos/modules/security/ca.nix#L67-L71
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    GIT_SSL_CAINFO = "/etc/ssl/certs/ca-certificates.crt";
    OPENSSL_X509_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
  };

  mapcats = f: x: concatStringsSep "\n" (mapAttrsToList f x);
}
