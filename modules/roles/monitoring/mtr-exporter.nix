# Copyright (C) develp GmbH 2025 All Rights Reserved
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib) head last;
  inherit (builtins) attrNames;

  nimbusVC = config.services.nimbus-validator-client;

  icmpJobFromHostname = domain: hostname: rec {
    address = "${hostname}.${domain}";
    name = "icmp:${address}";
    flags = [ "-c2" ];
  };

  tcpJobFromUrl = url: let
    matches = builtins.match "^[a-zA-Z]+://([^/:?#]+):([0-9]+).*" url;
  in
    if matches == null then throw "invalid URL"
    else let
      port = last matches;
    in rec {
      address = head matches;
      name = "tcp:${address}:${port}";
      flags = [ "-c2 --tcp -P ${port}" ];
    };
in {
  services.mtr-exporter = {
    enable = true;
    port = config.ports.monitoring.mtrExporter.http;
    address = "0.0.0.0";
    jobs = [
      { name = "icmp:cf-dns-icmp";     address = "one.one.one.one";                             flags = [ "-c2" ]; }
      { name = "icmp:cachix-icmp";     address = "cachix.org";                                  flags = [ "-c2" ]; }
      { name = "icmp:hetzner-icmp";    address = "fsn1-speed.hetzner.com";                      flags = [ "-c2" ]; }
      { name = "icmp:metrics-node-01"; address = "node-01.tsw-tyo1.lido.metrics.vpn.develp.co"; flags = [ "-c2" ]; }
      { name = "icmp:metrics-node-02"; address = "node-02.tsw-tyo1.lido.metrics.vpn.develp.co"; flags = [ "-c2" ]; }
    ]
    # Monitor all other hosts using ICMP check.
    ++ map (icmpJobFromHostname "develp.co")     (attrNames inputs.self.nixosConfigurations)
    ++ map (icmpJobFromHostname "vpn.develp.co") (attrNames inputs.self.nixosConfigurations)
    # Monitor health for BNs used by local VC using TCP check.
    ++ lib.optionals nimbusVC.enable (map tcpJobFromUrl nimbusVC.settings.beacon-node);

    package = pkgs.callPackage ../../pkgs/mtr-exporter {};
  };
}
