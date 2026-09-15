# Copyright (C) develp GmbH 2024 All Rights Reserved
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../lib.nix lib) baseServiceConfig;

  cfg = config.services.web3signer;

  web3signerNotifyWrapper = pkgs.replaceVarsWith {
    src = ./web3signer-notify-wrapper.sh;
    isExecutable = true;
    replacements = {
      web3signer = cfg.package;
      inherit (cfg.settings) metrics-port;
      inherit (pkgs) curl gawk runtimeShell;
    };
  };

  yaml = pkgs.formats.yaml {};
  removeNull = k: v: v != null;
  cleanSettings = lib.filterAttrs removeNull cfg.settings;
  configFile = yaml.generate "web3signer.yaml" cleanSettings;
in {
  imports = [
    # Optional slashing-protection database: options, PostgreSQL provisioning,
    # role password, schema migrations, and the settings pointing at it.
    ./slashing-db.nix
  ];

  inherit (import ./options.nix {inherit lib pkgs;}) options;

  config = lib.mkIf cfg.enable {
    environment.etc."ethereum/web3signer.yaml".source = configFile;

    systemd.services.web3signer = {
      description = "Web3Signer";
      wantedBy = lib.mkAfter [ "multi-user.target" ];

      serviceConfig = lib.mkMerge [
        baseServiceConfig
        {
          # FIXME: cleanup after moving keys to StateDirectory
          # web3signer group is used for /var/lib/.develp
          User = "web3signer-dynamic";
          Group = "web3signer-dynamic";

          StateDirectory = "web3signer::ro";
          WorkingDirectory = "%S/web3signer";

          MemoryDenyWriteExecute = false; # setting this option is incompatible with JIT

          NotifyAccess = "all";
          TimeoutStartSec = "infinity";
          Type = "notify";

          ExecStart = "${web3signerNotifyWrapper} --config-file=${configFile} eth2";
        }
      ];
    };
  };
}
