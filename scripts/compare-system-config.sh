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

IS_GITHUB_ACTION=${GITHUB_ACTIONS:-false}
SYSTEM_DIFFS_DIR=${SYSTEM_DIFFS_DIR:-"./system-diffs"}

PR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
PR_HEAD=$(git rev-parse HEAD)
MASTER_HEAD=$(git merge-base origin/master HEAD)

if [[ ! -d "./machines/" ]]; then
  echo "Error: './machines/' directory not found" >&2
  exit 1
fi

MACHINES=${MACHINES:-"all"}

if [[ "$MACHINES" == "all" ]]; then
  git checkout -q "$MASTER_HEAD"
  MACHINES=$(find ./machines/ -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
  if [[ -z "$MACHINES" ]]; then
    echo "Warning: No machines found in ./machines/ directory"
    exit 1
  fi
  git checkout -q "$PR_HEAD"
fi

function log_info()    { echo -e "\033[0;34m[INFO]\033[0m    $1" >&2; }
function log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1" >&2; }
function log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $1" >&2; }
function log_error()   { echo -e "\033[0;31m[ERROR]\033[0m   $1" >&2; }

trap "git checkout -q $PR_BRANCH" EXIT

function dependencies_diff_for_machine() {
  local master_config=$1 pr_config=$2 machine=$3
  local diff_file="${SYSTEM_DIFFS_DIR}/${machine}.diff"

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
    echo ${deps_diff} \
      | grep -v '^source:' \
      | sed -e 's/\x1b\[[0-9;]*m//g' \
      || true
  )
  if [[ -n "${deps_diff}" ]]; then
    echo -e "Dependencies diff:\n${deps_diff}" >> "${diff_file}"
  else
    echo "No dependencies diff detected." >> "${diff_file}"
  fi
}

function detect_systemd_services_updates_for_machine() {
  local master_config=$1 pr_config=$2 machine=$3
  local diff_file="${SYSTEM_DIFFS_DIR}/${machine}.diff"

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

  echo "Services to restart: ${SERVICES_TO_RESTART[*]}" >> "${diff_file}"
  echo "Services to start: ${SERVICES_TO_START[*]}" >> "${diff_file}"
  echo "Services to stop: ${SERVICES_TO_STOP[*]}" >> "${diff_file}"

}

function generate_machine_config() {
  local machine="${1}"
  local branch="${2}"
  log_info "Building master configuration for ${machine}..."
  git checkout -q "${branch}"
  if [[ ! -d "machines/${machine}" ]]; then
    log_warning "Skipping missing machine: ${machine}"
    return
  fi
  nix build --no-link --print-out-paths \
    '.#nixosConfigurations."'${machine}'".config.system.build.toplevel'
}

function generate_machine_diff() {
  local machine=$1

  master_config=$(generate_machine_config "${machine}" "${MASTER_HEAD}")
  pr_config=$(generate_machine_config "${machine}" "${PR_HEAD}")

  detect_systemd_services_updates_for_machine "${master_config}" "${pr_config}" "${machine}"
  dependencies_diff_for_machine "${master_config}" "${pr_config}" "${machine}"

  log_success "Diff generation complete for ${machine}"
}

function generate_all_diffs() {
  rm -rf "${SYSTEM_DIFFS_DIR}"
  mkdir -p "${SYSTEM_DIFFS_DIR}"
  for machine in $MACHINES; do
    generate_machine_diff "$machine"
  done
}


function main() {
  generate_all_diffs
  if [[ "$IS_GITHUB_ACTION" == "false" ]]; then
    log_info "Displaying summary on stdout:"
    ./scripts/system_diff_summary.py --diff-folder "$SYSTEM_DIFFS_DIR"
  fi
  log_success "NixOS diff generation completed successfully"
}

main "$@"
