{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, openssl
}:

let
  version = "0.12.4";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/microsoft/apm/releases/download/v${version}/apm-darwin-arm64.tar.gz";
      hash = "sha256-E1TrY2orhPA5OKO9iJAXUpj1dlDm2FB/LQhNPGbBD9A=";
      dir = "apm-darwin-arm64";
    };
    "x86_64-linux" = {
      url = "https://github.com/microsoft/apm/releases/download/v${version}/apm-linux-x86_64.tar.gz";
      hash = "sha256-qb5q+58z9jWY0Rp94QKXIv0mAaouyuv+gvSQPhKiOlI=";
      dir = "apm-linux-x86_64";
    };
  };

  source = sources.${stdenv.hostPlatform.system}
    or (throw "apm: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "apm";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  sourceRoot = source.dir;

  nativeBuildInputs = lib.optional stdenv.isLinux autoPatchelfHook;

  # The Linux PyInstaller bundle ships most shared libs in _internal/ but
  # omits OpenSSL — _ssl and _hashlib expect libssl.so.3 / libcrypto.so.3
  # from the system. Provide them here so autoPatchelfHook can resolve.
  buildInputs = lib.optionals stdenv.isLinux [ openssl ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/apm $out/bin
    cp -r . $out/lib/apm/
    chmod +x $out/lib/apm/apm
    ln -s $out/lib/apm/apm $out/bin/apm

    runHook postInstall
  '';

  meta = with lib; {
    description = "Agent Package Manager — the NPM for AI-native development";
    homepage = "https://github.com/microsoft/apm";
    license = licenses.mit;
    mainProgram = "apm";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
