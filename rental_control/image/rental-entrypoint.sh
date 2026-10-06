#!/usr/bin/env bash
set -Eeuo pipefail

readonly bootstrap=/usr/local/sbin/pod-ssh-bootstrap.sh
readonly expected_bootstrap_sha256=4539200ae2284a2b6ec76becc4ed5b55e75db684c5f28fd9c05233621b1676f0

fail() {
  printf 'BENCHMARK_IMAGE_ENTRYPOINT:FAILED:%s\n' "$1" >&2
  exit "${2:-70}"
}

[[ -x "$bootstrap" ]] || fail SSH_BOOTSTRAP_SCRIPT_MISSING 71
printf '%s  %s\n' "$expected_bootstrap_sha256" "$bootstrap" \
  | sha256sum -c - >/dev/null \
  || fail SSH_BOOTSTRAP_SCRIPT_HASH_MISMATCH 72

(( $# == 1 )) || fail MANAGED_WORKER_MODE_REQUIRED 73
[[ "$1" == "__MANAGED_WORKER_V1__" ]] || fail MANAGED_WORKER_MODE_REQUIRED 73

exec "$bootstrap" -- /usr/local/sbin/rental-job-anchor.py
