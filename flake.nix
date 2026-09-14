# Copyright (C) develp GmbH 2026 All Rights Reserved
{
  description = "Develp Infra NixOS Modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05-small";
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cachix = {
      url = "github:cachix/cachix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:numtide/nixos-anywhere";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixos-stable.follows = "nixpkgs";
        disko.follows = "disko";
      };
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }: let
      forAllSystems = function: nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system: function ( import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
          config.allowUnfree = true;
        })
      );
      machines = import ./machines { inherit self inputs; lib = nixpkgs.lib; };
    in {
      overlays.default = final: prev: let
        inherit (prev) callPackage;
        inherit (prev.stdenv.hostPlatform) system;
      in rec {
        inherit (inputs.ragenix.packages.${system}) ragenix;
        inherit (inputs.cachix.packages.${system}) cachix;
        inherit (inputs.nixos-anywhere.packages.${system}) nixos-anywhere;

        commit-boost = callPackage ./pkgs/commit-boost {};
        go-ethereum  = callPackage ./pkgs/go-ethereum {};
        mtr-exporter = callPackage ./pkgs/mtr-exporter {};
        nethermind   = callPackage ./pkgs/nethermind {};
        secrets      = callPackage ./pkgs/secrets {};
        web3signer   = callPackage ./pkgs/web3signer {};
      };

      packages = forAllSystems (pkgs: {
        inherit (pkgs) secrets ragenix cachix nixos-anywhere
          mtr-exporter go-ethereum commit-boost nethermind web3signer;
      });

      nixosModules = {
        default      = ./modules;
        commit-boost = ./services/commit-boost/;
        go-ethereum  = ./services/go-ethereum/;
        nethermind   = ./services/nethermind/;
        nimbus       = ./services/nimbus/;
        web3signer   = ./services/web3signer/;
      };
    };
}
