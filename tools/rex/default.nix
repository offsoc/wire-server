# WARNING: GENERATED FILE, DO NOT EDIT.
# This file is generated by running hack/bin/generate-local-nix-packages.sh and
# must be regenerated whenever local packages are added or removed, or
# dependencies are added or removed.
{ mkDerivation
, async
, attoparsec
, base
, bytestring
, clock
, dns
, exceptions
, gitignoreSource
, http-types
, iproute
, lib
, mtl
, network
, optparse-applicative
, prometheus
, text
, tinylog
, unordered-containers
, wai
, warp
}:
mkDerivation {
  pname = "rex";
  version = "0.3.0";
  src = gitignoreSource ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    async
    attoparsec
    base
    bytestring
    clock
    dns
    exceptions
    http-types
    iproute
    mtl
    network
    optparse-applicative
    prometheus
    text
    tinylog
    unordered-containers
    wai
    warp
  ];
  description = "Scrape and expose restund metrics for prometheus";
  license = lib.licenses.agpl3Only;
  mainProgram = "rex";
}
