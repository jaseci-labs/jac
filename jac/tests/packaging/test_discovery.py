"""Unit tests for jaclang.packaging.discovery."""

from __future__ import annotations

import os
from pathlib import Path

from jaclang.packaging import (
    JacPackage,
    find_packages,
    iter_jaclang_data_files,
)


def _mkpkg(root: Path, name: str, files: dict[str, str] | None = None) -> Path:
    pkg = root / name
    pkg.mkdir(parents=True, exist_ok=True)
    (pkg / "__init__.jac").write_text("")
    for rel, body in (files or {}).items():
        target = pkg / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body)
    return pkg


def test_find_packages_ignores_non_jac_and_hidden_and_python_packages(
    tmp_path: Path,
) -> None:
    _mkpkg(tmp_path, "myapp")
    _mkpkg(tmp_path, ".hidden")
    _mkpkg(tmp_path, "_private")
    (tmp_path / "pyonly").mkdir()
    (tmp_path / "pyonly" / "__init__.py").write_text("")
    (tmp_path / "nopkg" / "nested").mkdir(parents=True)

    pkgs = find_packages([str(tmp_path), str(tmp_path), "", "/nonexistent"])
    assert [p.name for p in pkgs] == ["myapp"]
    assert isinstance(pkgs[0], JacPackage)


def test_iter_sources_walks_tree_and_builds_dotted_names(tmp_path: Path) -> None:
    _mkpkg(
        tmp_path,
        "myapp",
        files={
            "core/__init__.jac": "",
            "core/greeter.jac": "",
            "utils/__init__.jac": "",
            "utils/helpers.jac": "",
            "notes.txt": "",  # non-.jac must be ignored
            ".jac/cache/stale.jac": "",  # hidden subdir must be skipped
        },
    )
    (pkg,) = find_packages([str(tmp_path)])
    by_name = {s.module_name: s for s in pkg.iter_sources()}

    assert set(by_name) == {
        "myapp",
        "myapp.core",
        "myapp.core.greeter",
        "myapp.utils",
        "myapp.utils.helpers",
    }
    assert by_name["myapp.core.greeter"].relative_path == os.path.join(
        "myapp", "core", "greeter.jac"
    )


def test_iter_jaclang_data_files_includes_bootstrap_modresolver() -> None:
    """Regression guard: modresolver.jac is load-bearing for frozen-app bootstrap."""
    import jaclang

    jaclang_root = os.path.dirname(jaclang.__file__)
    files = list(iter_jaclang_data_files())
    assert files

    for abs_path, rel_dir in files:
        assert abs_path.startswith(jaclang_root)
        assert os.path.isfile(abs_path)
        assert rel_dir.split(os.sep, 1)[0] == "jaclang"

    assert any(
        p.endswith(os.path.join("jac0core", "modresolver.jac")) for p, _ in files
    )
