{
  claude-history-src,
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "claude-history";
  version = "0.1.51";

  src = claude-history-src;

  cargoHash = "sha256-dIaKrngvzQDIejKq61oqp5N8xJmnOHbgZFsm+aDlk2U=";

  doCheck = false;

  meta = {
    description = "Fuzzy-search Claude Code conversation history";
    homepage = "https://github.com/raine/claude-history";
    license = lib.licenses.mit;
    mainProgram = "claude-history";
  };
}
