# WARNING: GENERATED FILE, DO NOT EDIT.
# This file is generated by running hack/bin/generate-local-nix-packages.sh and
# must be regenerated whenever local packages are added or removed, or
# dependencies are added or removed.
{ mkDerivation
, aeson
, aeson-diff
, aeson-pretty
, array
, asn1-encoding
, asn1-types
, async
, attoparsec
, base
, base16-bytestring
, base64-bytestring
, bytestring
, bytestring-conversion
, Cabal
, case-insensitive
, containers
, cookie
, cql
, cql-io
, crypton
, crypton-x509
, cryptostore
, data-default
, data-timeout
, deriving-aeson
, directory
, errors
, exceptions
, extended
, extra
, filepath
, gitignoreSource
, haskell-src-exts
, hex
, hourglass
, HsOpenSSL
, http-client
, http-types
, kan-extensions
, lens
, lens-aeson
, lib
, memory
, mime
, monad-control
, mtl
, network
, network-uri
, optparse-applicative
, pem
, process
, proto-lens
, random
, raw-strings-qq
, regex-base
, regex-tdfa
, retry
, saml2-web-sso
, scientific
, split
, stm
, streaming-commons
, string-conversions
, tagged
, temporary
, text
, time
, transformers
, transformers-base
, unix
, unliftio
, uuid
, vector
, wai
, wai-route
, warp
, warp-tls
, websockets
, wire-message-proto-lens
, wreq
, xml
, yaml
}:
mkDerivation {
  pname = "integration";
  version = "0.1.0";
  src = gitignoreSource ./.;
  isLibrary = true;
  isExecutable = true;
  setupHaskellDepends = [
    base
    Cabal
    containers
    directory
    filepath
    haskell-src-exts
  ];
  libraryHaskellDepends = [
    aeson
    aeson-diff
    aeson-pretty
    array
    asn1-encoding
    asn1-types
    async
    attoparsec
    base
    base16-bytestring
    base64-bytestring
    bytestring
    bytestring-conversion
    case-insensitive
    containers
    cookie
    cql
    cql-io
    crypton
    crypton-x509
    cryptostore
    data-default
    data-timeout
    deriving-aeson
    directory
    errors
    exceptions
    extended
    extra
    filepath
    hex
    hourglass
    HsOpenSSL
    http-client
    http-types
    kan-extensions
    lens
    lens-aeson
    memory
    mime
    monad-control
    mtl
    network
    network-uri
    optparse-applicative
    pem
    process
    proto-lens
    random
    raw-strings-qq
    regex-base
    regex-tdfa
    retry
    saml2-web-sso
    scientific
    split
    stm
    streaming-commons
    string-conversions
    tagged
    temporary
    text
    time
    transformers
    transformers-base
    unix
    unliftio
    uuid
    vector
    wai
    wai-route
    warp
    warp-tls
    websockets
    wire-message-proto-lens
    wreq
    xml
    yaml
  ];
  license = lib.licenses.agpl3Only;
}
