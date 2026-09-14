rec {
  flake = builtins.getFlake (builtins.toString ./.);
  pkgs = import flake.inputs.nixpkgs {};
  lib = pkgs.lib;
  self = ./.;
  users = (import ./lib).usersInfo;
  system = builtins.currentSystem;
  packages = flake.outputs.packages."${system}";
  checks = flake.outputs.checks."${system}";
  inherit (flake.outputs) nixosConfigurations;
}
