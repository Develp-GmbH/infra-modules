#!/usr/bin/env bash

# This script generates NixOS system diffs and outputs a summary.
# It is designed to run either in a GitHub Actions pipeline or locally.
# When running in GitHub Actions pipeline:
# - The summary will be available as a PR comment and in the workflow run summary.
# - Artifacts containing detailed diffs will be uploaded to the workflow run.
# When running locally:
# - The output of the diffs will be printed to stdout for review.
# Additional Notes:
# - If run locally, you can export the `MACHINES` variable with a space-delimited
#   list of machine names to specify which machines to process.
# - If `MACHINES` is not set, the script will default to scanning the `./machines/`
#   directory for available machines.

set -euo pipefail

function log_info()    { echo -e "\033[0;34m[INFO]\033[0m    $1" >&2; }
function log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1" >&2; }
function log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $1" >&2; }
function log_error()   { echo -e "\033[0;31m[ERROR]\033[0m   $1" >&2; }

function dependencies_diff_for_machine() {
  local master_config=$1 pr_config=$2 machine=$3
  local summary_file="${SYSTEMS_DIFF_DIR}/${machine}.summary"

  if [[ -z "${pr_config}" ]]; then
    log_warning "Machine config missing in PR! No such config: ${pr_config}"
    return 0
  fi
  log_info "Generating dependencies diff for ${machine}..."

  if ! deps_diff=$(nix store diff-closures "${master_config}" "${pr_config}" 2>&1); then
    log_error "Failed to generate dependencies diff for ${machine}"
    # Show stderr from failed diff-closures command.
    echo "${deps_diff}"
    return 1
  fi

  deps_diff=$(
    echo "${deps_diff}" \
      | grep -v '^source:' \
      | sed -e 's/\x1b\[[0-9;]*m//g' \
      || true
  )
  if [[ -n "${deps_diff}" ]]; then
    echo -e "Dependencies diff:\n${deps_diff}" >> "${summary_file}"
  else
    echo "No dependencies diff detected." >> "${summary_file}"
  fi
}

function detect_systemd_services_updates_for_machine() {
  local master_config=$1 pr_config=$2 machine=$3
  local summary_file="${SYSTEMS_DIFF_DIR}/${machine}.summary"

  master_systemd_dir="$master_config/etc/systemd/system/"
  pr_systemd_dir="$pr_config/etc/systemd/system/"

  if [[ ! -d "$master_systemd_dir" ]]; then
    log_error "Master systemd directory does not exist: $master_systemd_dir"
    return 1
  fi

  if [[ ! -d "$pr_systemd_dir" ]]; then
    log_error "PR systemd directory does not exist: $pr_systemd_dir"
    return 1
  fi

  declare -a SERVICES_TO_RESTART=()
  declare -a SERVICES_TO_START=()
  declare -a SERVICES_TO_STOP=()

  log_info "Analyzing systemd services which will be started or restarted on $machine."
  for service_file in "$pr_systemd_dir"/*.service; do
    if [ -f "$service_file" ]; then
      service_name=$(basename "$service_file")
      master_service_file="$master_systemd_dir/$service_name"
      service_basename="${service_name%.service}"

      if [ -f "$master_service_file" ]; then
        if ! diff -q "$service_file" "$master_service_file" >/dev/null; then
          SERVICES_TO_RESTART+=("$service_basename")
        fi
      else
        SERVICES_TO_START+=("$service_basename")
      fi
    fi
  done

  log_info "Analyzing systemd services which will be stopped on $machine."
  for service_file in "$master_systemd_dir"/*.service; do
    if [ -f "$service_file" ]; then
      service_name=$(basename "$service_file")
      pr_service_file="$pr_systemd_dir/$service_name"
      service_basename="${service_name%.service}"

      if [ ! -f "$pr_service_file" ]; then
        SERVICES_TO_STOP+=("$service_basename")
      fi
    fi
  done

  mkdir -p "$(dirname "${summary_file}")"
  {
    echo "Services to restart: ${SERVICES_TO_RESTART[*]}"
    echo "Services to start: ${SERVICES_TO_START[*]}"
    echo "Services to stop: ${SERVICES_TO_STOP[*]}"
  } > "${summary_file}"
}

function nix_derivation_diff_for_machine() {
  local master_config=$1 pr_config=$2 machine=$3
  local diff_file="${SYSTEMS_DIFF_DIR}/${machine}.diff"

  if [[ -z "${pr_config}" ]]; then
    log_warning "Machine config missing in PR! No such config: ${pr_config}"
    return 0
  fi
  log_info "Analyzing derivation differences for $machine."
  nix-diff --color=always --word-oriented --context=6 "${master_config}" "${pr_config}" \
      > "${diff_file}"
}

function generate_machine_config() {
  local machine="${1}" commit="${2}" branch="${3}"
  log_info "Building ${branch} (${commit:0:8}) configuration for: ${machine}"
  git checkout -q "${commit}"
  if [[ ! -d "machines/${machine}" ]]; then
    log_warning "Skipping missing machine: ${machine}"
    return
  fi
  nix build --no-link --print-out-paths \
    '.#nixosConfigurations."'"${machine}"'".config.system.build.toplevel'
}

function generate_machine_diff() {
  local machine=$1

  master_config=$(generate_machine_config "${machine}" "${MASTER_HEAD}" "master")
  pr_config=$(generate_machine_config "${machine}" "${PR_HEAD}" "pr")

  detect_systemd_services_updates_for_machine "${master_config}" "${pr_config}" "${machine}"
  dependencies_diff_for_machine "${master_config}" "${pr_config}" "${machine}"
  nix_derivation_diff_for_machine "${master_config}" "${pr_config}" "${machine}"

  log_success "Diff generation complete for ${machine}"
}

[[ -n $(git status --porcelain) ]] && { log_error "Stash or commit your Git repo changes!" >&2; exit 1; }
[[ ! -d "./machines/" ]]           && { log_error "No './machines/' directory found!" >&2;      exit 1; }
[[ $# -ne 1 ]]                     && { log_warning "Usage: $0 <machine>" >&2;                  exit 1; }
[[ ! -d "./machines/${1}" ]]       && { log_error "No '${1}' found in ./machines/ dir!" >&2;    exit 1; }

IS_GITHUB_ACTION=${GITHUB_ACTIONS:-false}
SYSTEMS_DIFF_DIR=${SYSTEMS_DIFF_DIR:-"./systems-diff"}

PR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
PR_HEAD=$(git rev-parse HEAD)
MASTER_HEAD=$(git merge-base origin/master HEAD)

trap 'git checkout -q "${PR_BRANCH}"' EXIT

generate_machine_diff "${1}"
if [[ "${IS_GITHUB_ACTION}" == "false" ]]; then
  log_info "Displaying summary on stdout:"
  systems-diff-summary --diff-folder "${SYSTEMS_DIFF_DIR}"
  echo
fi
log_success "NixOS diff generation completed successfully"
