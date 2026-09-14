{
  config,
  pkgs,
  lib,
  ...
}: let
  excludedServicesList = [
    "audit"
    "dbus-broker"
    "domainname"
    "emergency"
    "firewall"
    "folder-size-metrics"
    "fstrim"
    "generate-shutdown"
    "getty"
    "kmod"
    "logrotate"
    "mdmonitor"
    "modprob"
    "motd"
    "mount"
    "network"
    "NetworkManager"
    "nscd"
    "rescue"
    "resolvconf"
    "save-hwclock"
    "serial-getty"
    "suid"
    "systemd"
    "tailscale-"
    "user"
  ];
in {
  services.prometheus.exporters.systemd = {
      enable= true;
      port = config.ports.monitoring.systemdExporter.http;
      extraFlags = [
        "--systemd.collector.unit-exclude=^(${lib.concatStringsSep "|" excludedServicesList }).*\.service$|.*\.(socket|device|mount|slice|target|timer|scope|path)$"
      ];
    };

    # To avoid err="couldn't get dbus connection: read unix @->/run/dbus/system_bus_socket: EOF"
    services.dbus.implementation = "broker";
}
