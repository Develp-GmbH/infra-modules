{ config, lib, ... }:

{
  options.host-info = with lib; rec {
    type = mkOption {
      type = types.enum [ "vm" "server" ];
      default = if config.host-info.isDebugVM then "vm" else "server";
      example = "server";
      description = "Whether this host is a vm or a server.";
    };

    isDebugVM = mkOption {
      type = types.bool;
      default = false;
      example = "false";
      description = "Whether this configuration is a VM variant with extra debug functionality.";
    };

    configPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = [ "machines/server/solunska-server" ];
      description = "The configuration path for this host relative to the repo root.";
    };

    sshKey = mkOption {
      type = types.nullOr types.str;
      default = "";
      example = "ssh-ed25519 AAAAC3Nza";
      description = "The public ssh key for this host.";
    };
  };

  config = {
    assertions = [
      {
        assertion = config.host-info.type != null;
        message = "host-info.type must be defined for every host";
      }
      {
        assertion = config.host-info.isDebugVM != null;
        message = "host-info.isDebugVM must be defined for every host";
      }
      {
        assertion = config.host-info.configPath != null;
        message = "host-info.configPath must be defined for every host";
      }
      {
        assertion = config.host-info.sshKey != null;
        message = "host-info.sshKey must be defined for every host";
      }
    ];
  };
}
