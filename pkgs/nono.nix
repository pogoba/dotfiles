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
  name = "nononix";

  src = nono-src;

  cargoHash = "sha256-4mXycVJHveQWOdYjKZ7jOuyiePrNZAeDf21CCEvsbp8=";

  buildInputs = [ dbus ];
  nativeBuildInputs = [
    pkg-config
    autoPatchelfHook
  ];

  doCheck = false;


  postInstall = ''
    mkdir -p $out/bin
    cat > $out/bin/nononix <<'EOF'
    #!/bin/sh
    set -x
    sudo -E capsh --keep=1 --gid=$(id -g) --groups=$(id -G | tr ' ' ',') --uid=$(id -u) --inh=cap_sys_admin --addamb=cap_sys_admin -- -c "nono run --profile nix-claude --allow-cwd --allow-command sudo -- $@"
    EOF
    chmod +x $out/bin/nononix
  '';

  meta = {
    mainProgram = "nononix";
  };
}

