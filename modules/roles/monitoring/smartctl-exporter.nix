{ config, ... }:

{
  services.prometheus.exporters = {
    smartctl = {
      enable = true;
      port = config.ports.monitoring.smartctlExporter.metrics;
      user = "root";
      group = "root";
    };
  };
}
