{ mkDerivation, aeson, aeson-pretty, amazonka, amazonka-autoscaling
, amazonka-core, amazonka-ec2, amazonka-elb, amazonka-route53
, async, attoparsec, base, base64-bytestring, bytestring, conduit
, conduit-extra, containers, directory, exceptions, fetchgit
, filepath, lens, lifted-base, mtl, natural-sort
, optparse-applicative, pretty-show, process, random, resourcet
, scientific, semigroups, stdenv, tagged, text, time, unix
, unordered-containers, vector, vk-posix-pty
}:
mkDerivation {
  pname = "upcast";
  version = "0.1.1.0";
  src = fetchgit {
    url = "git@github.com:zalora/upcast.git";
    sha256 = "dafb9a1b43bc65fe62db7dd1010e8a92d36f6d499e53b5d3dec6b090b8aa24d4";
    rev = "e8892117b5e50dc1b215faaf4ef25eda8c8ec97c";
  };
  isLibrary = true;
  isExecutable = true;
  buildDepends = [
    aeson aeson-pretty amazonka amazonka-autoscaling amazonka-core
    amazonka-ec2 amazonka-elb amazonka-route53 async attoparsec base
    base64-bytestring bytestring conduit conduit-extra containers
    directory exceptions filepath lens lifted-base mtl natural-sort
    optparse-applicative pretty-show process random resourcet
    scientific semigroups tagged text time unix unordered-containers
    vector vk-posix-pty
  ];
  license = stdenv.lib.licenses.mit;
}
