{
  nono-src,
  lib,
  rustPlatform,
  dbus,
  pkg-config,
  autoPatchelfHook,
  ...
}:

rustPlatform.buildRustPackage rec {
  name = "nono-pogoba";

  src = nono-src;

  cargoHash = "sha256-4mXycVJHveQWOdYjKZ7jOuyiePrNZAeDf21CCEvsbp8=";

  buildInputs = [ dbus ];
  nativeBuildInputs = [
    pkg-config
    autoPatchelfHook
  ];

  doCheck = false;

  meta = {
    mainProgram = "nono";
  };
}

