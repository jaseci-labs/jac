"""Test that install_bridge populates the version-scoped cache and that
find_bridge_lib resolves from it without the dev fallback or JAC_RUST_BRIDGES_PATH.
"""

from __future__ import annotations

import pathlib

import pytest


def _find_regex_so() -> pathlib.Path | None:
    here = pathlib.Path(__file__).resolve()
    for base in (here.parents[2], here.parents[3]):
        for build in ("release", "debug"):
            p = base / "target" / build / "libjac_bridge_regex.so"
            if p.is_file():
                return p
    return None


@pytest.fixture()
def regex_so_path() -> pathlib.Path:
    p = _find_regex_so()
    if p is None:
        pytest.skip(
            "libjac_bridge_regex.so not built; run: cargo build --release -p jac-bridge-regex"
        )
    return p


def test_install_and_find(
    regex_so_path: pathlib.Path, tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """install_bridge copies .so into cache; find_bridge_lib resolves it."""
    import sys

    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[3] / "jac"))
    from jaclang.compiler.rust_bridge import install_bridge
    from jaclang.compiler.rust_bridge._finder import find_bridge_lib

    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path))
    monkeypatch.delenv("JAC_RUST_BRIDGES_PATH", raising=False)
    monkeypatch.delenv("JAC_BRIDGE_DEV_FALLBACK", raising=False)

    dest = install_bridge(regex_so_path, version="1.0.0")

    assert dest.is_file(), f"install_bridge did not create {dest}"
    assert dest.name == regex_so_path.name

    found = find_bridge_lib("regex")
    assert found is not None, (
        "find_bridge_lib returned None — cache install did not populate the search path"
    )
    assert found.resolve() == dest.resolve()


def test_install_version_layout(
    regex_so_path: pathlib.Path, tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Cache layout is <cache>/jac/rust-bridges/<crate>/<ver>/<target>/<lib>."""
    import sys

    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[3] / "jac"))
    from jaclang.compiler.rust_bridge import install_bridge

    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path))

    dest = install_bridge(regex_so_path, version="2.3.4")

    parts = dest.parts
    cache_idx = next(i for i, p in enumerate(parts) if p == "rust-bridges")
    crate, version = parts[cache_idx + 1], parts[cache_idx + 2]
    assert crate == "regex"
    assert version == "2.3.4"


def test_no_fallback_without_install(
    tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """find_bridge_lib returns None when cache is empty and fallback is off."""
    import sys

    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[3] / "jac"))
    from jaclang.compiler.rust_bridge._finder import find_bridge_lib

    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path))
    monkeypatch.delenv("JAC_RUST_BRIDGES_PATH", raising=False)
    monkeypatch.delenv("JAC_BRIDGE_DEV_FALLBACK", raising=False)

    assert find_bridge_lib("regex") is None
