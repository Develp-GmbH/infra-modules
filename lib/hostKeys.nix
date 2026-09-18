{ lib }:

nixosConfigurations:

let
  inherit (lib) hasPrefix attrValues mapAttrs filterAttrs;

  # Avoid duplicate keys cauing 'has non-unique elements' error.
  isNotVm = name: !(hasPrefix "vm-" name);
  filterVms = name: _: isNotVm name;
  nixosConfigsNoVms = filterAttrs filterVms nixosConfigurations;

  # Extract sshKey attribute if it's available.
  getSshKey = name: config:
    if isNotVm name
    then config.config.host-info.sshKey or null
    else null;
in
  # Arguments:
  attrValues (mapAttrs getSshKey nixosConfigsNoVms)
