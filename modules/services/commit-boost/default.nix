{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib)
    mkEnableOption mkOption mkIf mapAttrs'
    types filterAttrs nameValuePair;

  eachCommitBoost = config.services.commit-boost;

  toml = pkgs.formats.toml {};
  removeNulls = obj:
    if lib.isAttrs obj then
      lib.filterAttrs (k: v: v != null) (
        lib.mapAttrs (k: v: removeNulls v) obj
      )
    else if lib.isList obj then
      map removeNulls obj
    else
      obj;

in {
  options = {
    services = {
      commit-boost = mkOption {
        default = {};
        type = types.attrsOf (types.submodule {
          options = {
            enable = mkEnableOption "Commit-Boost sidecar service.";

            package = mkOption {
              type = types.package;
              default = pkgs.commit-boost or (throw "commit-boost package not available");
              description = "Package to use for Commit-Boost.";
            };

            settings = mkOption {
              description = "TOML config file settings for Commit-Boost.";
              default = {};

              type = types.submodule {
                freeformType = toml.type;
                options = {
                  chain = mkOption {
                    type =  types.nullOr (types.enum ["Mainnet" "Sepolia" "Hoodi"]);
                    default = "Mainnet";
                    description = "Chain spec ID. Supported values: Mainnet, Holesky, Sepolia, Helder, Hoodi.";
                  };

                  pbs = mkOption {
                    type = types.submodule {
                      freeformType = toml.type;
                      options = {
                        with_signer = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Whether to enable the PBS module to request signatures from the Signer module.";
                        };

                        host = mkOption {
                          type = types.str;
                          default = "127.0.0.1";
                          description = "Host to receive BuilderAPI calls from beacon node.";
                        };

                        port = mkOption {
                          type = types.port;
                          default = 18550;
                          description = "Port to receive BuilderAPI calls from beacon node.";
                        };

                        relay_check = mkOption {
                          type = types.bool;
                          default = true;
                          description = "Whether to forward 'status' calls to relays or skip and return 200.";
                        };

                        timeout_get_header_ms = mkOption {
                          type = types.int;
                          default = 950;
                          description = "Timeout in milliseconds for the 'get_header' call to relays.";
                        };

                        timeout_get_payload_ms = mkOption {
                          type = types.int;
                          default = 4000;
                          description = "Timeout in milliseconds for the 'submit_blinded_block' call to relays.";
                        };

                        timeout_register_validator_ms = mkOption {
                          type = types.int;
                          default = 3000;
                          description = "Timeout in milliseconds for the 'register_validator' call to relays.";
                        };

                        skip_sigverify = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Whether to skip signature verification of headers.";
                        };

                        min_bid_eth = mkOption {
                          type = types.either types.float types.str;
                          default = 0.0;
                          description = "Minimum bid in ETH that will be accepted from 'get_header'.";
                        };

                        late_in_slot_time_ms = mkOption {
                          type = types.int;
                          default = 2000;
                          description = "How late in milliseconds in the slot is considered 'late'.";
                        };

                        extra_validation_enabled = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Whether to enable extra validation of get_header responses.";
                        };

                        rpc_url = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = "Execution Layer RPC url to use for extra validation.";
                        };
                      };
                    };
                    default = {};
                    description = "PBS module configuration.";
                  };

                  relays = mkOption {
                    type = types.listOf (types.submodule {
                      freeformType = toml.type;
                      options = {
                        id = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = "Relay ID to use in telemetry.";
                        };

                        url = mkOption {
                          type = types.str;
                          description = "Relay URL in the format scheme://pubkey@host";
                        };

                        headers = mkOption {
                          type = types.nullOr (types.attrsOf types.str);
                          default = null;
                          description = "Headers to send with each request for this relay.";
                        };

                        enable_timing_games = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Whether to enable timing games for this relay.";
                        };

                        target_first_request_ms = mkOption {
                          type = types.nullOr types.int;
                          default = null;
                          description = "Target time in slot when to send the first header request.";
                        };

                        frequency_get_header_ms = mkOption {
                          type = types.nullOr types.int;
                          default = null;
                          description = "Frequency in ms to send get_header requests.";
                        };
                      };
                    });
                    default = [];
                    description = "List of relay configurations.";
                  };

                  metrics = mkOption {
                    type = types.nullOr (types.submodule {
                      freeformType = toml.type;
                      options = {
                        enabled = mkOption {
                          type = types.bool;
                          default = true;
                          description = "Whether to collect metrics.";
                        };

                        host = mkOption {
                          type = types.str;
                          default = "127.0.0.1";
                          description = "Host to listen on for metrics.";
                        };

                        start_port = mkOption {
                          type = types.port;
                          default = 10000;
                          description = "Starting port for Prometheus scrapes.";
                        };
                      };
                    });
                    default = null;
                    description = "Metrics collection configuration.";
                  };

                  logs = mkOption {
                    type = types.submodule {
                      freeformType = toml.type;
                      options = {
                        stdout = mkOption {
                          type = types.submodule {
                            freeformType = toml.type;
                            options = {
                              enabled = mkOption {
                                type = types.bool;
                                default = true;
                                description = "Whether to enable stdout logging.";
                              };

                              level = mkOption {
                                type = types.enum ["trace" "debug" "info" "warn" "error"];
                                default = "info";
                                description = "Log level for stdout.";
                              };

                              use_json = mkOption {
                                type = types.bool;
                                default = false;
                                description = "Log in JSON format.";
                              };

                              color = mkOption {
                                type = types.bool;
                                default = true;
                                description = "Whether to enable ANSI color codes.";
                              };
                            };
                          };
                          default = {};
                        };

                        file = mkOption {
                          type = types.nullOr (types.submodule {
                            freeformType = toml.type;
                            options = {
                              enabled = mkOption {
                                type = types.bool;
                                default = false;
                                description = "Whether to enable file logging.";
                              };

                              level = mkOption {
                                type = types.enum ["trace" "debug" "info" "warn" "error"];
                                default = "info";
                                description = "Log level for file logging.";
                              };

                              use_json = mkOption {
                                type = types.bool;
                                default = true;
                                description = "Log in JSON format.";
                              };

                              dir_path = mkOption {
                                type = types.str;
                                default = "/var/logs/commit-boost";
                                description = "Path to the log directory.";
                              };

                              max_files = mkOption {
                                type = types.nullOr types.int;
                                default = null;
                                description = "Maximum number of log files to keep.";
                              };
                            };
                          });
                          default = null;
                        };
                      };
                    };
                    default = {};
                    description = "Logging configuration.";
                  };
                };
              };
            };
          };
        });
        description = "Commit-Boost instances configuration.";
      };
    };
  };

  config = mkIf (eachCommitBoost != {}) {
    environment.etc = mapAttrs'
      (commitBoostName: cfg:
        nameValuePair "commit-boost-${commitBoostName}/config.toml" {
          source = toml.generate "commit-boost-${commitBoostName}.toml" (removeNulls cfg.settings);
        }
      )
      eachCommitBoost;

    systemd.services = mapAttrs'
      (commitBoostName: cfg: let
        serviceName = "commit-boost-${commitBoostName}";
        configFile = toml.generate "commit-boost-${commitBoostName}.toml" (removeNulls cfg.settings);
      in
        nameValuePair serviceName (mkIf cfg.enable {
          enable = true;
          description = "Commit-Boost Service (${commitBoostName})";
          requires = ["network.target"];
          wantedBy = ["multi-user.target"];

          environment = {
            CB_CONFIG = configFile;
            CB_METRICS_PORT = builtins.toString cfg.settings.metrics.start_port;
          };

          serviceConfig = {
            DynamicUser = true;

            # Hardening measures
            PrivateTmp = "true";
            ProtectSystem = "full";
            PrivateDevices = "true";
            MemoryDenyWriteExecute = "true";
            WorkingDirectory = "%S/${serviceName}";
            StateDirectory = serviceName;

            Restart = "on-failure";
            ExecStart = "${cfg.package}/bin/commit-boost-pbs";
          };
        })
      )
      eachCommitBoost;
  };
}
