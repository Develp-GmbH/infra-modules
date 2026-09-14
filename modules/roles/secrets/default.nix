{ config, inputs, options, lib, ... }:

let
  eachServiceCfg = config.secrets.services;
  isDebugVM = config.host-info.isDebugVM;

  cfg = config.secrets;

  sshKey =
    if isDebugVM then
      config.virtualisation.vmVariant.host-info.sshKey
    else
      config.host-info.sshKey;

  ageSecretOpts = builtins.head (
    builtins.head options.age.secrets.type.nestedTypes.elemType.getSubModules
  ) .imports;

  secretDir = let
    machineSecretDir = config.host-info.configPath + "/secrets";
    vmSecretDir = ../../types/vm/secrets;
  in if isDebugVM then vmSecretDir else machineSecretDir;
in
{
  imports = [
    inputs.ragenix.nixosModules.default
  ];

  options.secrets = with lib; {
    extraKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "ssh-ed25519 AAAAC3Nza"
        "ssh-ed25519 AAAACSNss"
      ];
      description = "Extra keys which can decrypt the secrets.";
    };

    services = mkOption {
      type = types.attrsOf (
        types.submodule (
          { config, ... }:
          let
            serviceName = config._module.args.name;
          in
          {
            options = {
              encryptedSecretDir = mkOption {
                type = types.path;
                default = secretDir;
              };
              secrets = mkOption {
                default = { };
                type = types.attrsOf (
                  types.submoduleWith {
                    modules = [
                      ageSecretOpts
                      (
                        { name, ... }:
                        let
                          secretName = name;
                        in
                        {
                          config = {
                            name = "${serviceName}/${secretName}";
                            file = lib.mkDefault (config.encryptedSecretDir + "/${serviceName}/${secretName}.age");
                          };
                        }
                      )
                    ];
                  }
                );
              };
              extraKeys = mkOption {
                type = types.listOf types.str;
                default = [ ];
                example = [
                  "ssh-ed25519 AAAAC3Nza"
                  "ssh-ed25519 AAAACSNss"
                ];
                description = "Extra keys which can decrypt the secrets.";
              };
              nix-file = mkOption {
                default = builtins.toFile "${serviceName}-secrets.nix" ''
                  let
                    hostKey = [
                      "${sshKey}"
                    ];
                    extraKeysPerService = [
                      ${lib.concatMapStringsSep "\n    " (key:
                        "\"${key}\""
                      ) (lib.unique (lib.remove sshKey config.extraKeys))}
                    ];
                    extraKeysPerHost = [
                      ${lib.concatMapStringsSep "\n    " (key:
                        "\"${key}\""
                      ) cfg.extraKeys}
                    ];
                  in {
                    ${concatMapStringsSep "\n" (
                      n: "\"${n}.age\".publicKeys = hostKey ++ extraKeysPerService ++ extraKeysPerHost;"
                    ) (builtins.attrNames config.secrets)}
                  }
                '';
                type = types.path;
              };
            };
          }
        )
      );
      default = { };
      example = {
        service1.secrets.secretA = { };
        service1.secrets.secretB = { };
        service2.secrets.secretC = { };
        cachix-deploy.secrets.token = {
          path = "/etc/cachix-agent.token";
        };
      };
      description = mdDoc "Per-service attrset of encryptedSecretDir and secrets";
    };
  };

  config = lib.mkIf (eachServiceCfg != { }) {
    # Provide helper for use with reloadTriggers or restartTriggers.
    _module.args.hashSecrets = secrets: map (name:
      builtins.hashFile "sha256" config.age.secrets.${name}.file
    ) secrets;

    age.secrets = lib.pipe eachServiceCfg [
      (lib.mapAttrsToList (
        serviceName: service:
        lib.mapAttrsToList (
          secretName: config: lib.nameValuePair "${serviceName}/${secretName}" config
        ) service.secrets
      ))
      lib.concatLists
      lib.listToAttrs
    ];
  };
}
