{ pkgs, lib, ... }:
let
  version = "0.38.4";
in
pkgs.stdenv.mkDerivation {
  pname = "texra-cli";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@texra-ai/cli/-/cli-${version}.tgz";
    hash = "sha256-Jg0CMFdwSQTNIuWy2IgsyuIz1LuZWjQnfPFV/7gGgUU=";
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/texra-cli
    cp -r . $out/lib/texra-cli/
    mkdir -p $out/bin
    makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/texra \
      --add-flags $out/lib/texra-cli/dist/bin/texra.js
    runHook postInstall
  '';

  meta = {
    description = "Texra AI CLI";
    homepage = "https://www.npmjs.com/package/@texra-ai/cli";
    # license = lib.licenses.unfree;
    mainProgram = "texra";
    platforms = lib.platforms.unix;
  };
}
