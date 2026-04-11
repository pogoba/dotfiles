{pkgs, inputs, ...}: {


  home.packages = with pkgs; [
    inputs.llm-agents.packages.${stdenv.hostPlatform.system}.pi
  ];

  home.file.".pi/agent/models.json".source = ./pi-models.json;

  sops.secrets.morpheus_token = {
    path = "%r/morpheus_token"; # %r gets replaced with your $XDG_RUNTIME_DIR
  };
}
