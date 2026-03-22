{ pkgs, ... }: pkgs.openssh.overrideAttrs (_finalAttrs: _previousAttrs: {
  pname = "openssh-patched";
  patches = (_previousAttrs.patches or []) ++ [ ./openssh-stall-hint.patch ];
})
