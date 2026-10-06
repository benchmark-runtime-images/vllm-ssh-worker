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

(( $# > 0 )) || fail VLLM_ARGUMENTS_REQUIRED 73
[[ "$1" != "__LIVE_ARGS_REQUIRED__" ]] || fail VLLM_ARGUMENTS_REQUIRED 73

host_seen=0
expect_host_value=0
for argument in "$@"; do
  if (( expect_host_value )); then
    [[ "$argument" == "127.0.0.1" ]] || fail VLLM_NON_LOOPBACK_HOST_REJECTED 74
    host_seen=1
    expect_host_value=0
    continue
  fi
  case "$argument" in
    --host)
      expect_host_value=1
      ;;
    --host=127.0.0.1)
      host_seen=1
      ;;
    --host=*)
      fail VLLM_NON_LOOPBACK_HOST_REJECTED 74
      ;;
  esac
done
(( expect_host_value == 0 )) || fail VLLM_HOST_VALUE_MISSING 75
(( host_seen == 1 )) || fail VLLM_LOOPBACK_HOST_REQUIRED 76

exec "$bootstrap" -- vllm serve "$@"
