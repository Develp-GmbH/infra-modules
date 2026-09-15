#!@runtimeShell@

set -o errexit
set -o nounset

export PATH="@web3signer@/bin:@curl@/bin:@gawk@/bin:$PATH"

check() {
  echo "check: will update systemd service ready when validator keys are loaded"
  while true; do
    validators_loaded="$(curl -s localhost:@metrics-port@/metrics | awk '/^signing_signers_loaded_count /{print int($2)}')"
    if [[ -n "${validators_loaded}" ]]; then
      echo "check: ${validators_loaded} keys loaded"
      echo "check: notifying systemd that service is ready"
      systemd-notify --ready --status="${validators_loaded} keys loaded"
      return 0
    else
      echo "check: waiting for validator keys loaded"
      systemd-notify --status="waiting for validator keys loaded"
    fi
    sleep 1
  done
}

if [[ -n "${NOTIFY_SOCKET}" ]]; then
  check &
else
  echo "check: not a 'notify' type service, will not run"
fi

web3signer "$@"
