#!/usr/bin/env python3
"""Offline capability self-test for the neutral multi-model runtime image."""

from __future__ import annotations

import importlib
import importlib.metadata as metadata
import json
import platform
import sys


EXPECTED_PACKAGES = {
    "vllm": "0.31.0",
    "torch": "2.13.0+cu130",
    "transformers": "5.17.0",
    "mistral-common": "1.11.0",
}

MODULES = (
    "vllm.model_executor.models.gpt_oss",
    "vllm.model_executor.models.bailing_moe_v3",
    "vllm.model_executor.models.gemma4",
    "vllm.model_executor.models.nemotron_h",
    "vllm.model_executor.models.glm4_moe_lite",
    "vllm.models.kimi_k3",
    "vllm.model_executor.models.mistral",
    "vllm.reasoning.gptoss_reasoning_parser",
    "vllm.reasoning.ling3_reasoning_parser",
    "vllm.reasoning.gemma4_engine_reasoning_parser",
    "vllm.reasoning.nemotron_v3_engine_reasoning_parser",
    "vllm.reasoning.glm47_moe_reasoning_parser",
    "vllm.reasoning.mistral_reasoning_parser",
    "vllm.tool_parsers.gptoss_tool_parser",
    "vllm.tool_parsers.ling3_tool_parser",
    "vllm.tool_parsers.gemma4_engine_tool_parser",
    "vllm.tool_parsers.glm47_moe_tool_parser",
    "vllm.tool_parsers.mistral_tool_parser",
)


def main() -> int:
    actual_packages = {
        name: metadata.version(name) for name in EXPECTED_PACKAGES
    }
    failures: list[str] = []
    if platform.python_version() != "3.12.3":
        failures.append(f"python:{platform.python_version()}")
    for name, expected in EXPECTED_PACKAGES.items():
        if actual_packages[name] != expected:
            failures.append(f"{name}:{actual_packages[name]}")

    imports: dict[str, str] = {}
    for module in MODULES:
        try:
            importlib.import_module(module)
        except Exception as exc:  # pragma: no cover - executed in image build
            imports[module] = f"FAIL:{type(exc).__name__}:{exc}"
            failures.append(module)
        else:
            imports[module] = "PASS"

    result = {
        "schema": "benchmark.runtime_offline_selftest.v1",
        "network_required": False,
        "python": platform.python_version(),
        "packages": actual_packages,
        "imports": imports,
        "status": "PASS" if not failures else "FAIL",
    }
    print(json.dumps(result, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())

