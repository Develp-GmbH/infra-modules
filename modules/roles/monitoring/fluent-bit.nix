# Copyright (C) develp GmbH 2024 All Rights Reserved
{
  config,
  lib,
  ...
}: let
  host = lib.removeSuffix ".develp.co" config.networking.fqdnOrHostName;
in {
  services.fluent-bit = {
    enable = true;
    graceLimit = 30;
    settings = {
      service = {
        flush = "1";
        log_level = "info";
        grace = "30";
        http_server = true;
        http_listen = "0.0.0.0";
        http_port = config.ports.monitoring.fluent-bit.http;
      };
      pipeline = {
        inputs = [
          {
            name = "systemd";
            tag = "systemd.*";
            read_from_tail = true;
            db = "/var/lib/fluent-bit/positions.db";
            max_entries = "1000";
          }
        ];
        filters = [
          {
            name = "grep";
            match = "systemd.nethermind-*";
            exclude = "MESSAGE .*(TooManyPeers|engine_newPayloadV4|0000000000000).*";
          }
          {
            name = "grep";
            match = "systemd.nimbus-beacon-node*";
            exclude = "MESSAGE .*topics=\"(libp2p|peer_proto).*\".*";
          }
          {
            name = "record_modifier";
            match = "systemd.*";
            Allowlist_key = [
              "MESSAGE"
              "_SYSTEMD_UNIT"
            ];
          }
        ];
        outputs = map (host: {
          inherit host;
          name = "loki";
          match = "systemd.*";
          port = config.ports.monitoring.loki.http;
          uri = "/loki/api/v1/push";
          labels = "job=systemd-journal, host=${host}, unit=$_SYSTEMD_UNIT";
          remove_keys = ["_SYSTEMD_UNIT"];
          header = "Content-Type application/json";
          drop_single_key = "raw";
          line_format = "json";
        }) [
          "node-01.ovh-os-de2.hq.metrics.vpn.develp.co"
          "node-02.tsw-tyo1.lido.metrics.vpn.develp.co"
        ];
      };
    };
  };

  systemd.services.fluent-bit = {
    serviceConfig = {
      StateDirectory = "fluent-bit";
      WorkingDirectory = "%S/fluent-bit";
      LimitNOFILE = 32000;
    };
  };
}
