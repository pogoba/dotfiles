You are on NixOS. Make missing programs or libraries available via `nix-shell -p`. Consult `nix-locate` to search all packages for a filename or build a derivation to obtain a path to it. Don't attempt to use `ls` or `find` etc in `/nix/store` because it is big.

For cross-project context exploration, check `~/`, `~/dev/`, `~/dev/github/` and `/scratch/okelmann/` for already checked out source code.

When debugging complex projects with slow development iterations, gather evidence and diagnose systematically before going into a deep dive to develop a fix. Do NOT guess at root causes or propose speculative theories. If unsure, propose the most likely theory, a test to validate the hypothesis, and summarize how a fix could work.
