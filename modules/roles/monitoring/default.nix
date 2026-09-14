# Copyright (C) develp GmbH 2024 All Rights Reserved
{
  imports = [
    ./fluent-bit.nix
    ./netdata.nix
    ./mtr-exporter.nix
    ./smartctl-exporter.nix
    ./systemd-exporter.nix
    ./chrony-exporter.nix
  ];

  users.groups.monitoring = {};
}
