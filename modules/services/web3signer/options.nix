{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  yaml = pkgs.formats.yaml {};
in {
  options.services.web3signer = {
    enable = mkEnableOption "Web3Signer remote signer service.";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../pkgs/web3signer {};
      defaultText = "pkgs.web3signer";
      description = "Web3Signer package to use.";
    };

    settings = mkOption {
      description = "YAML config file settings for Web3Signer.";
      default = {};
      type = types.submodule {
        freeformType = yaml.type;
        options = {
          http-listen-host = mkOption {
            type = types.str;
            default = "localhost";
            description = "Host on which HTTP listens.";
          };
          http-listen-port = mkOption {
            type = types.port;
            default = 9000;
            description = "Port on which HTTP listens";
          };
          http-host-allowlist = mkOption {
            type = types.listOf types.str;
            default = ["localhost" "127.0.0.1"];
            description = "A list of hostnames to allow access to the REST APIs.";
          };
          logging = mkOption {
            type = types.enum ["OFF" "FATAL" "WARN" "INFO" "DEBUG" "TRACE" "ALL"];
            default = "INFO";
            description = "Logging verbosity level.";
          };
          metrics-enabled = mkOption {
            type = types.bool;
            default = false;
            description = "Enables the metrics exporter.";
          };
          metrics-host = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = "The host on which Prometheus accesses metrics.";
          };
          metrics-port = mkOption {
            type = types.port;
            default = 9001;
            description = "The port (TCP) on which Prometheus accesses metrics.";
          };
          metrics-host-allowlist = mkOption {
            type = types.listOf types.str;
            default = ["localhost" "127.0.0.1"];
            description = "A list of hostnames to allow access to the Web3Signer metrics.";
          };
          "eth2.key-manager-api-enabled" = mkOption {
            type = types.bool;
            default = false;
            description = "Enables the key manager API.";
          };
          "eth2.keystores-password-file" = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "File that contains the password used by all keystores. Cannot be set if --keystores-passwords-path is also specified.";
          };
          "eth2.keystores-path" = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Directory that stores the keystore files. Keystore files must use a .json file extension.";
          };
          "eth2.network" = mkOption {
            type = types.str;
            default = "mainnet";
            description = "Predefined network configuration. Accepts a predefined network name, or file path or URL to a YAML configuration file.";
          };
          "eth2.slashing-protection-enabled" = mkOption {
            type = types.bool;
            default = true;
            description = "Enables Web3Signer slashing protection. If true, then all signing operations are validated against historical data before signing.";
          };
        };
      };
    };
  };
}
