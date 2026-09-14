#!/usr/bin/env bash
# Copyright (C) develp GmbH 2024 All Rights Reserved

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <ssh-host> <machine>"
  exit 1
fi

ssh_host_before="$1"
machine="$2"

set -x
nixos-anywhere --debug --build-on auto --copy-host-keys --flake ".#$machine" "$ssh_host_before"
echo "NixOS installation complete."

echo "All done."
