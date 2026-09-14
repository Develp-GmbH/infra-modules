# Copyright (C) develp GmbH 2025 All Rights Reserved
{ lib, self }:
let
  inherit (lib) hasPrefix attrValues mapAttrs filterAttrs;
  inherit (self.outputs) nixosConfigurations;

  # Avoid duplicate keys cauing 'has non-unique elements' error.
  isNotVm = name: !(hasPrefix "vm-" name);
  filterVms = name: config: isNotVm name;
  nixosConfigsNoVms = filterAttrs filterVms nixosConfigurations;

  # Extract sshKey attribute if it's available.
  getSshKey = name: config:
    if isNotVm name && config ? config.host-info.sshKey
    then config.config.host-info.sshKey
    else null;
in
  attrValues (mapAttrs getSshKey nixosConfigsNoVms)
