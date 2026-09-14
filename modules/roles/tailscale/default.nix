# Copyright (C) develp GmbH 2024 All Rights Reserved
{ config, lib, hashSecrets, ... }:

let
  tailscaleExtraFlags = [
    "--ssh=true"
    "--hostname=${lib.removeSuffix ".develp.co" config.networking.fqdnOrHostName}"
    # MagicDNS hijacks /etc/resolv.conf and can break host DNS
    "--accept-dns=false"
  ];
  fleetTag = "lido";
  port = config.ports.tailscale.relayPort;
in {
  secrets.services.tailscale.secrets.auth-key = { mode = "700"; };
  systemd.services.tailscaled-autoconnect.restartTriggers = hashSecrets [ "tailscale/auth-key" ];

  networking.firewall.allowedUDPPorts = [port];

  services.tailscale = {
    enable = true;
    # One-off auth keys can only be used once, regenerate on host re-bootstrapping.
    # https://tailscale.com/docs/features/access-control/auth-keys#types-of-auth-keys
    authKeyFile = config.age.secrets."tailscale/auth-key".path;
    extraUpFlags = tailscaleExtraFlags ++ ["--advertise-tags=tag:${fleetTag}"];
    extraSetFlags = tailscaleExtraFlags ++ ["--relay-server-port=${toString port}"];
  };
}
