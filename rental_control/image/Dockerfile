ARG BASE_IMAGE=vllm/vllm-openai@sha256:c1c9f6fd5c109ba7f0546a59f5b2f15fb87f64c77782e90a27b648b42a8e67c3
FROM ${BASE_IMAGE}

ARG BOOTSTRAP_SHA256=4539200ae2284a2b6ec76becc4ed5b55e75db684c5f28fd9c05233621b1676f0

# Packages are installed once while building the immutable image. Billed Pod
# startup performs no package-manager or mirror access.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server \
        iproute2 \
        procps \
        ca-certificates \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub \
    && install -d -m 0755 /run/sshd

COPY --chmod=0755 rental_control/pod-ssh-bootstrap.sh /usr/local/sbin/pod-ssh-bootstrap.sh
COPY --chmod=0755 rental_control/image/rental-entrypoint.sh /usr/local/sbin/rental-entrypoint.sh

RUN printf '%s  %s\n' "${BOOTSTRAP_SHA256}" /usr/local/sbin/pod-ssh-bootstrap.sh \
      | sha256sum -c - \
    && command -v /usr/sbin/sshd >/dev/null \
    && command -v /usr/bin/ssh-keygen >/dev/null \
    && /usr/bin/ssh-keygen -A \
    && /usr/sbin/sshd -t \
    && rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub \
    && python3 - <<'PY'
import importlib.metadata as metadata
import platform

expected = {
    "vllm": "0.31.0",
    "torch": "2.13.0+cu130",
    "transformers": "5.17.0",
}
actual = {name: metadata.version(name) for name in expected}
if actual != expected or platform.python_version() != "3.12.3":
    raise SystemExit(f"runtime matrix drift: python={platform.python_version()} packages={actual}")
PY

LABEL org.opencontainers.image.title="Neutral benchmark worker runtime" \
      org.opencontainers.image.description="Digest-locked vLLM runtime with prebuilt SSH bootstrap" \
      benchmark.runtime.profile="text-vllm-0.31.0-cu130-ssh-v1" \
      benchmark.runtime.vllm="0.31.0" \
      benchmark.runtime.python="3.12.3" \
      benchmark.runtime.torch="2.13.0+cu130" \
      benchmark.runtime.cuda="13.0.2" \
      benchmark.runtime.transformers="5.17.0" \
      benchmark.ssh.bootstrap.sha256="4539200ae2284a2b6ec76becc4ed5b55e75db684c5f28fd9c05233621b1676f0"

ENTRYPOINT ["/usr/local/sbin/rental-entrypoint.sh"]
CMD ["__LIVE_ARGS_REQUIRED__"]
