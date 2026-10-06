#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf 'BENCHMARK_SSH_BOOTSTRAP:%s\n' "$1"
}

fail() {
  log "FAILED:$1" >&2
  exit "${2:-74}"
}

test_mode="${BENCHMARK_BOOTSTRAP_TEST_MODE:-0}"
root_prefix=""
if [[ "$test_mode" == "1" ]]; then
  root_prefix="${BENCHMARK_BOOTSTRAP_ROOT:?BENCHMARK_BOOTSTRAP_ROOT is required in test mode}"
fi

sshd_bin="${root_prefix}/usr/sbin/sshd"
ssh_keygen_bin="${root_prefix}/usr/bin/ssh-keygen"
ssh_dir="${root_prefix}/root/.ssh"
authorized_keys="${ssh_dir}/authorized_keys"
host_key_dir="${root_prefix}/etc/ssh"
sshd_dropin_dir="${host_key_dir}/sshd_config.d"
sshd_dropin="${sshd_dropin_dir}/99-benchmark-access.conf"
run_dir="${root_prefix}/run/sshd"

[[ -x "$sshd_bin" ]] || fail SSH_BOOTSTRAP_SSHD_ABSENT 75
[[ -x "$ssh_keygen_bin" ]] || fail SSH_BOOTSTRAP_SSH_KEYGEN_ABSENT 76

public_key="${BENCHMARK_SSH_PUBLIC_KEY:-}"
if [[ ! "$public_key" =~ ^(ssh-(ed25519|rsa)|ecdsa-sha2-nistp(256|384|521))[[:space:]][A-Za-z0-9+/]+={0,3}$ ]]; then
  fail SSH_BOOTSTRAP_PUBLIC_KEY_INVALID 77
fi

install -d -m 0700 "$ssh_dir"
touch "$authorized_keys"
chmod 0600 "$authorized_keys"
if ! grep -qxF "$public_key" "$authorized_keys"; then
  printf '%s\n' "$public_key" >> "$authorized_keys"
fi
log AUTHORIZED_KEY_READY

install -d -m 0755 "$host_key_dir" "$sshd_dropin_dir" "$run_dir"
if ! find "$host_key_dir" -maxdepth 1 -type f -name 'ssh_host_*_key' -size +0c -print -quit | grep -q .; then
  "$ssh_keygen_bin" -A || fail SSH_BOOTSTRAP_HOST_KEY_GENERATION_FAILED 78
  log HOST_KEYS_GENERATED
else
  log HOST_KEYS_PRESERVED
fi
if ! find "$host_key_dir" -maxdepth 1 -type f -name 'ssh_host_*_key' -size +0c -print -quit | grep -q .; then
  fail SSH_BOOTSTRAP_HOST_KEYS_UNAVAILABLE 79
fi

cat > "$sshd_dropin" <<'EOF'
Port 22
ListenAddress 0.0.0.0
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
AllowTcpForwarding yes
GatewayPorts no
PermitTunnel no
X11Forwarding no
EOF
chmod 0644 "$sshd_dropin"

"$sshd_bin" -t || fail SSH_BOOTSTRAP_CONFIG_INVALID 80
log CONFIG_VALID

listener_ready() {
  if [[ "$test_mode" == "1" ]]; then
    [[ -f "$run_dir/listening" ]]
    return
  fi
  if command -v ss >/dev/null 2>&1; then
    ss -H -ltn | awk '$4 ~ /:22$/ { found=1 } END { exit !found }'
    return
  fi
  (exec 3<>/dev/tcp/127.0.0.1/22) >/dev/null 2>&1
}

if ! listener_ready; then
  "$sshd_bin" || fail SSH_BOOTSTRAP_SSHD_START_FAILED 81
fi

deadline=$((SECONDS + 15))
until listener_ready; do
  (( SECONDS >= deadline )) && fail SSH_BOOTSTRAP_SSHD_NOT_LISTENING 82
  sleep 1
done
log READY

if [[ "${1:-}" == "--" ]]; then
  shift
fi
(( $# > 0 )) || fail SSH_BOOTSTRAP_WORKLOAD_MISSING 83
exec "$@"
