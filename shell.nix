# Copyright (C) develp GmbH 2026 All Rights Reserved
{ pkgs, config, extraPkgs, ... }:

let
  repl = pkgs.writeShellApplication {
    name = "repl";
    text = ''
      nix repl --file "$(dirname $$DIRENV_FILE)/repl.nix";
    '';
  };
  # Age and Agenix support specifying multiple identities.
  agenixWrapper = pkgs.writeShellScriptBin "agenix" ''
    AGENIX_ARGS=""
    if [[ -n "$AGE_IDENTITIES" ]]; then
      AGENIX_ARGS="-i $(echo "$AGE_IDENTITIES" | sed -z '$ s/\n$//' | tr '\n' ' ' | sed -e 's/ / -i /g')"
    fi
    exec ${pkgs.ragenix}/bin/ragenix $AGENIX_ARGS $@
  '';
in
  pkgs.mkShellNoCC {
    packages = with pkgs; [
      agenixWrapper age-plugin-yubikey rage jq just repl util-linux
      nix-eval-jobs nix-output-monitor nixos-rebuild
    ] ++ extraPkgs;

    # Verify Cachix configuration
    shellHook = ''
      source .envrc.completion
      source .envrc.nix-config
      ./scripts/cachix_setup.sh
    '';
  }
