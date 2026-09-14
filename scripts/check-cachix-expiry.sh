#!/usr/bin/env bash
set -euo pipefail

CACHIX_NAME="${1:-}"

if ! curl -fs -o /dev/null -H "Authorization: Bearer ${CACHIX_AUTH_TOKEN}" \
    https://app.cachix.org/api/v1/user; then
  echo "Can't authenticate on cachix API:"
  echo "Check your CACHIX_AUTH_TOKEN is correct and not expired"
  exit 1
fi

if ! curl -fs -o /dev/null --netrc-file ~/.config/nix/netrc \
    "https://${CACHIX_NAME}.cachix.org/nix-cache-info"; then
  echo "Can't login to remote cache:"
  echo "Run \`cachix use ${CACHIX_NAME}\` to update the token"
  exit 1
fi
