"""Unit tests for jaclang.packaging.discovery."""

from __future__ import annotations

import os
from pathlib import Path

from jaclang.packaging import iter_jaclang_data_files, iter_user_jac_sources


def _mk(path: Path, body: str = "") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body)


def test_iter_user_jac_sources_filters_correctly(tmp_path: Path) -> None:
    for rel in [
        "myapp/__init__.jac",
        "myapp/core/__init__.jac",
        "myapp/core/greeter.jac",
        "myapp/notes.txt",  # non-.jac: ignored
        "myapp/.cache/stale.jac",  # hidden subdir: skipped
    ]:
        _mk(tmp_path / rel)
    # hidden / dunder / python-only roots must be ignored
    _mk(tmp_path / ".hidden" / "__init__.jac")
    _mk(tmp_path / "_priv" / "__init__.jac")
    _mk(tmp_path / "pyonly" / "__init__.py")

    got = list(
        iter_user_jac_sources([str(tmp_path), str(tmp_path), "", "/nonexistent"])
    )
    srcs = [s for s, _ in got]

    assert len(got) == 3  # myapp/__init__, core/__init__, greeter
    assert all(s.endswith(".jac") for s in srcs)
    assert not any(
        seg in s for s in srcs for seg in (".hidden", ".cache", "_priv", "pyonly")
    )


def test_iter_jaclang_data_files_includes_modresolver() -> None:
    """Regression guard: modresolver.jac is load-bearing for frozen-app bootstrap."""
    import jaclang

    root = os.path.dirname(jaclang.__file__)
    files = list(iter_jaclang_data_files())
    assert files
    assert all(p.startswith(root) for p, _ in files)
    assert all(rel.split(os.sep, 1)[0] == "jaclang" for _, rel in files)
    assert any(
        p.endswith(os.path.join("jac0core", "modresolver.jac")) for p, _ in files
    )
