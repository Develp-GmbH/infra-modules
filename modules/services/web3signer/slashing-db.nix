# Copyright (C) develp GmbH 2024 All Rights Reserved
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption mkEnableOption mkDefault mkBefore types;

  cfg = config.services.web3signer;
  slashing-db = cfg.slashing-db;

  pgPort = config.services.postgresql.settings.port;

  dbUrl = "jdbc:postgresql://127.0.0.1:${toString pgPort}/${slashing-db.name}";

in {
  options.services.web3signer.slashing-db = {
    enable =
      mkEnableOption "Web3Signer slashing protection database"
      // {default = true;};

    name = mkOption {
      type = types.str;
      default = "web3signer";
      description = "Database name for slashing protection.";
    };

    user = mkOption {
      type = types.str;
      default = "web3signer";
      description = ''
        Role the signer connects as. Must equal the database name, since
        ensureDBOwnership requires it.
      '';
    };
  };

  config = mkIf (cfg.enable && slashing-db.enable) {
    # Point the signer at the database. mkDefault so a host can override.
    services.web3signer.settings = {
      "eth2.slashing-protection-enabled" = mkDefault true;
      "eth2.slashing-protection-db-url" = mkDefault dbUrl;
      "eth2.slashing-protection-db-username" = mkDefault slashing-db.user;
      "eth2.slashing-protection-pruning-enabled" = mkDefault true;
      "eth2.slashing-protection-pruning-at-boot-enabled" = mkDefault false;
    };

    services.postgresql = {
      enable = mkDefault true;
      # Between nixpkgs' stateVersion mkDefault (1000) and an explicit pin (100):
      # wins on signer-only hosts, yields to lido-keys-api where both run.
      package = lib.mkOverride 900 pkgs.postgresql_16;
      ensureDatabases = mkBefore [slashing-db.name];
      ensureUsers = mkBefore [
        {
          name = slashing-db.user;
          ensureDBOwnership = true;
        }
      ];
      # Scoped to exactly this database
      authentication = mkBefore ''
        host ${slashing-db.name} ${slashing-db.user} 127.0.0.1/32 trust
        host ${slashing-db.name} ${slashing-db.user} ::1/128      trust
      '';
    };

    # Slashing DB migrations
    systemd.services.web3signer-db-migrate = {
      description = "Web3Signer slashing protection schema migrations";
      after = ["postgresql.service"];
      requires = ["postgresql.service"];
      before = ["web3signer.service"];
      requiredBy = ["web3signer.service"];

      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.flyway}/bin/flyway"
          "-url=${dbUrl}"
          "-user=${slashing-db.user}"
          "-locations=filesystem:${cfg.package}/migrations/postgresql"
          "-connectRetries=10"
          "migrate"
        ];
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        NoNewPrivileges = true;
      };
    };
  };
}
