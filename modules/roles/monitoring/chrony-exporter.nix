# Copyright (C) develp GmbH 2025 All Rights Reserved
{ config, ... }:

{
  services.prometheus.exporters = {
    chrony = {
      enable = true;
      port = config.ports.monitoring.chronyExporter.metrics;
    };
  };
}
