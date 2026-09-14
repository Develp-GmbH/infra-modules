#!/usr/bin/env bash

export YLW='\033[1;33m'
export RED='\033[0;31m'
export BLU='\033[0;34m'
export B='\033[1m'
export R='\033[0m'

function nix_find_config() {
  nix config show "${1}" | grep "${2}" >/dev/null
}

os_name() {
    source /etc/os-release 2>/dev/null
    echo "${NAME}"
}

# Checking group ownership to identify installation type.
file_group() {
    UNAME=$(uname -s)
    if [[ "${UNAME}" == "Linux" ]]; then
        stat -Lc "%G" "${1}" 2>/dev/null
    elif [[ "${UNAME}" == "Darwin" ]]; then
        # Avoid using Nix GNU stat when in Nix shell.
        /usr/bin/stat -Lf "%Sg" "${1}" 2>/dev/null
    fi
}

function nix_install_type() {
    NIX_STORE_DIR_GROUP=$(file_group /nix/store)
    if [[ "$(os_name)" =~ NixOS ]]; then
        echo "nixos"
    else
        USER=$(id -un) # Missing in Docker.
        case "${NIX_STORE_DIR_GROUP}" in
            "nixbld")   echo "multi";;
            "30000")    echo "multi";;
            "(30000)")  echo "multi";;
            "wheel")    echo "single";;
            "users")    echo "single";;
            "${USER}")  echo "single";;
            "${UID}")   echo "single";;
            "(${UID})") echo "single";;
            "")         echo "none";
                        echo "No Nix installation detected!" >&2;;
            *)          echo "Unknown Nix installation type!" >&2; exit 1;;
        esac
    fi
}

if ! nix_find_config experimental-features flakes; then
  echo -e "${RED}${B}error:${R} Flakes not enabled in experimental-features in /etc/nix/nix.conf." >&2
  echo -e "${BLU}${B}info:${R} See ${B}docs/setting_up_a_dev_env.md${R} for more details." >&2
  exit 1
fi

if (nix_find_config trusted-users $USER || [[ $(nix_install_type) == "single" ]]) && ! nix_find_config substituters infra-lido.cachix.org; then
  echo -e "${YLW}${B}warning:${R} Adding your user to ${B}trusted-users${R} is equivalent to passwordless ${B}sudo${R}." >&2
  # If user is in trusted-users we just adjust ~/.config/nix/nix.conf.
  cachix use infra-lido
elif ! nix_find_config substituters infra-lido.cachix.org; then
  echo -e "${YLW}${B}info:${R} Running 'cachix use infra-lido' with 'sudo'..." >&2
  # If user is NOT in trusted-users its safer to just add cache to /etc/nix/nix.conf.
  HOME=/root sudo -E cachix use infra-lido
fi
