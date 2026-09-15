{ lib }:

nixosConfigurations:

{
  port,
  network ? null,
  enables,
}:

let
  enablesPath = lib.splitString "." enables;

  isEligibleHost = name: host: let
    isVM = lib.hasPrefix "vm-" name;
    onNetwork = if network == null then true
      else (host.config.services.ethereum.network or null) == network;
    serviceEnabled = lib.attrByPath enablesPath false host.config.services;
  in
    !isVM && onNetwork && serviceEnabled;

  queryHost = name: _: "${name}.vpn.develp.co:${toString port}";
in
  lib.pipe nixosConfigurations [
    (lib.filterAttrs isEligibleHost)
    (lib.mapAttrsToList queryHost)
  ]
