{ config, lib, pkgs, hashSecrets, ...}:

{
  secrets.services.cachix-deploy.secrets.token = { path = "/etc/cachix-agent.token"; };
  systemd.services.cachix-agent.restartTriggers = hashSecrets [ "cachix-deploy/token" ];

  services.cachix-agent = {
    enable = true;
    package = pkgs.cachix;
    name = lib.removeSuffix ".develp.co" config.networking.fqdnOrHostName;
  };
}
