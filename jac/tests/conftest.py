"""Pytest fixtures for jac/tests (extends repo-root conftest.py)."""

from __future__ import annotations

import os
from pathlib import Path

import pytest


def _llvm_shim_candidates() -> list[Path]:
    env = os.environ.get("JAC_LLVM_SHIM")
    if env and Path(env).is_file():
        return [Path(env)]
    here = Path(__file__).resolve().parents[1]
    names = (
        "libjacllvm.so",
        "libjacllvm.dylib",
        "jacllvm.dll",
    )
    roots = (
        here / "zig-out" / "lib",
        here / "jaclang" / "compiler" / "passes" / "native" / "llvm",
    )
    found: list[Path] = []
    for root in roots:
        for name in names:
            cand = root / name
            if cand.is_file():
                found.append(cand)
    return found


@pytest.fixture(scope="session", autouse=True)
def _ensure_llvm_shim_for_jac_compilation() -> None:
    """Point JAC_LLVM_SHIM at a built artifact when present (dev/CI)."""
    if os.environ.get("JAC_LLVM_SHIM"):
        return
    candidates = _llvm_shim_candidates()
    if candidates:
        os.environ["JAC_LLVM_SHIM"] = str(candidates[0])


def jac_compiler_available() -> bool:
    """Return True when the LLVM shim is present and .jac compilation should work."""
    return bool(_llvm_shim_candidates())


@pytest.fixture
def hermetic_hook_env() -> None:
    """Kernel-only bootstrap with product tier marked settled (no LLVM providers).

    Hook behavior tests register pure-Python stub plugins on top of this so
    dispatch is exercised without compiling product-tier .jac modules.
    """
    import jaclang.bootstrap as bootstrap
    import jaclang.jac0core.runtime as runtime_mod

    bootstrap.bootstrap_kernel()
    bootstrap._PRODUCT_STATE = bootstrap._BootstrapState.DONE
    runtime_mod._product_done[0] = False


@pytest.fixture
def require_jac_compiler() -> None:
    if not jac_compiler_available():
        pytest.skip(
            "libjacllvm.so not available — build the LLVM shim or set JAC_LLVM_SHIM"
        )
