{
  lib,
  callPackage,
  python3,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
  extrasuite-src,
}:

let
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = extrasuite-src + "/client";
  };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  # pyfpgrowth ships an sdist without declaring setuptools as a build dep.
  buildSystemOverlay = final: prev: {
    pyfpgrowth = prev.pyfpgrowth.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ final.resolveBuildSystem { setuptools = [ ]; };
    });
  };

  # Add drive.readonly so `docs pull` can read comments on files not created by
  # this OAuth app (drive.file alone only sees app-created files).
  scopePatchOverlay = _final: prev: {
    extrasuite = prev.extrasuite.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/extrasuite/client/credentials.py \
          --replace-fail \
            '"https://www.googleapis.com/auth/drive.file",' \
            '"https://www.googleapis.com/auth/drive.file", "https://www.googleapis.com/auth/drive.readonly",'
      '';
    });
  };

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      python = python3;
    }).overrideScope
      (lib.composeManyExtensions [
        pyproject-build-systems.overlays.wheel
        overlay
        buildSystemOverlay
        scopePatchOverlay
      ]);

  inherit (callPackage pyproject-nix.build.util { }) mkApplication;
in
mkApplication {
  venv = pythonSet.mkVirtualEnv "extrasuite-env" workspace.deps.default;
  package = pythonSet.extrasuite;
}
