# Neutral vLLM SSH worker runtime

This public repository builds a generic, immutable `linux/amd64` worker image
from the digest-pinned upstream vLLM 0.31.0 image. It adds OpenSSH and public
orchestration utilities at image-build time. Runtime startup performs no
package installation and keeps vLLM bound to `127.0.0.1`.

The repository and image contain no credentials, private keys, model weights,
benchmark cases, fixtures, graders, hidden references, client data, private
mappings, or internal source. A public key is supplied only at container
runtime and is not stored in the image.

Releases are consumed by immutable `ghcr.io/...@sha256:...` references. Mutable
tags are convenience labels and are never accepted by the live controller.

The additive multi-model profile derives from the already published hardened
runtime and adds only the public `mistral-common` package needed by the native
Mistral tokenizer path. Its build executes an offline import self-test for the
public model families used by the multi-model screening campaign. It does not
contain model weights, prompts, benchmark material, or credentials.
