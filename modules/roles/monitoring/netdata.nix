# Copyright (C) develp GmbH 2024 All Rights Reserved
{
  config,
  pkgs,
  ...
}: {
  services.netdata = {
    enable = true;
    configDir = {
      "stream.conf" = pkgs.writeText "stream.conf" ''
        [stream]
        enabled = yes
        destination = localhost:${toString config.ports.monitoring.netdata.http}
      '';
      "go.d/zfspool.conf" = pkgs.writeText "zfspool.conf" ''
        jobs:
          - name: zfspool
            binary_path: ${config.boot.zfs.package}/bin/zpool
      '';
    };
  };
}
