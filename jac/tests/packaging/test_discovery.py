"""Unit tests for ``jaclang.packaging.discovery``.

Fast, hermetic tests that build synthetic package layouts under ``tmp_path``
and assert the discovery API reports them correctly. No subprocesses, no
PyInstaller, no jaclang runtime bootstrapping.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from jaclang.packaging import (
    JacPackage,
    JacSource,
    find_packages,
    iter_jaclang_data_files,
)


def _mkpkg(root: Path, name: str, *, files: dict[str, str] | None = None) -> Path:
    """Create a Jac package (``<root>/<name>/__init__.jac`` plus any files)."""
    pkg = root / name
    pkg.mkdir(parents=True, exist_ok=True)
    (pkg / "__init__.jac").write_text("")
    for rel, body in (files or {}).items():
        target = pkg / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body)
    return pkg


class TestFindPackages:
    def test_finds_top_level_jac_package(self, tmp_path: Path) -> None:
        _mkpkg(tmp_path, "myapp")
        pkgs = find_packages([str(tmp_path)])
        assert [p.name for p in pkgs] == ["myapp"]
        assert pkgs[0].root == str(tmp_path / "myapp")

    def test_skips_dir_without_init_jac(self, tmp_path: Path) -> None:
        (tmp_path / "nonpkg").mkdir()
        (tmp_path / "nonpkg" / "file.jac").write_text("")
        assert find_packages([str(tmp_path)]) == []

    def test_skips_python_only_packages(self, tmp_path: Path) -> None:
        (tmp_path / "pyonly").mkdir()
        (tmp_path / "pyonly" / "__init__.py").write_text("")
        assert find_packages([str(tmp_path)]) == []

    def test_skips_hidden_and_dunder_dirs(self, tmp_path: Path) -> None:
        for name in (".hidden", "_private", "__pycache__"):
            _mkpkg(tmp_path, name)
        _mkpkg(tmp_path, "visible")
        assert [p.name for p in find_packages([str(tmp_path)])] == ["visible"]

    def test_dedupes_across_search_dirs(self, tmp_path: Path) -> None:
        _mkpkg(tmp_path, "myapp")
        pkgs = find_packages([str(tmp_path), str(tmp_path)])
        assert [p.name for p in pkgs] == ["myapp"]

    def test_ignores_missing_or_empty_search_dirs(self, tmp_path: Path) -> None:
        _mkpkg(tmp_path, "myapp")
        pkgs = find_packages(
            [
                "",
                str(tmp_path / "nonexistent"),
                str(tmp_path),
                None,  # type: ignore[list-item]
            ]
        )
        assert [p.name for p in pkgs] == ["myapp"]

    def test_returns_dataclass_instances(self, tmp_path: Path) -> None:
        _mkpkg(tmp_path, "myapp")
        (pkg,) = find_packages([str(tmp_path)])
        assert isinstance(pkg, JacPackage)
        # JacPackage is frozen
        with pytest.raises(Exception):
            pkg.name = "other"  # type: ignore[misc]


class TestIterSources:
    def test_enumerates_every_jac_file(self, tmp_path: Path) -> None:
        _mkpkg(
            tmp_path,
            "myapp",
            files={
                "core/__init__.jac": "",
                "core/greeter.jac": 'def greet() -> str { return "hi"; }',
                "utils/__init__.jac": "",
                "utils/helpers.jac": "",
            },
        )
        (pkg,) = find_packages([str(tmp_path)])
        sources = list(pkg.iter_sources())

        rels = sorted(s.relative_path for s in sources)
        assert rels == sorted(
            [
                os.path.join("myapp", "__init__.jac"),
                os.path.join("myapp", "core", "__init__.jac"),
                os.path.join("myapp", "core", "greeter.jac"),
                os.path.join("myapp", "utils", "__init__.jac"),
                os.path.join("myapp", "utils", "helpers.jac"),
            ]
        )

    def test_module_name_follows_package_layout(self, tmp_path: Path) -> None:
        _mkpkg(
            tmp_path,
            "myapp",
            files={
                "core/__init__.jac": "",
                "core/greeter.jac": "",
            },
        )
        (pkg,) = find_packages([str(tmp_path)])
        by_rel = {s.relative_path: s for s in pkg.iter_sources()}

        assert by_rel[os.path.join("myapp", "__init__.jac")].module_name == "myapp"
        assert (
            by_rel[os.path.join("myapp", "core", "__init__.jac")].module_name
            == "myapp.core"
        )
        assert (
            by_rel[os.path.join("myapp", "core", "greeter.jac")].module_name
            == "myapp.core.greeter"
        )

    def test_skips_hidden_subdirs(self, tmp_path: Path) -> None:
        _mkpkg(
            tmp_path,
            "myapp",
            files={
                ".jac/cache/stale.jac": "",
                "core/__init__.jac": "",
            },
        )
        (pkg,) = find_packages([str(tmp_path)])
        paths = [s.relative_path for s in pkg.iter_sources()]
        assert all(".jac" + os.sep not in p for p in paths), paths

    def test_ignores_non_jac_files(self, tmp_path: Path) -> None:
        _mkpkg(
            tmp_path,
            "myapp",
            files={
                "notes.txt": "irrelevant",
                "core/__init__.jac": "",
                "core/module.py": "print('nope')",
            },
        )
        (pkg,) = find_packages([str(tmp_path)])
        exts = {os.path.splitext(s.path)[1] for s in pkg.iter_sources()}
        assert exts == {".jac"}


class TestJacSource:
    def test_is_frozen(self) -> None:
        src = JacSource(path="/x.jac", module_name="x", relative_path="x.jac")
        with pytest.raises(Exception):
            src.path = "/y.jac"  # type: ignore[misc]


class TestIterJaclangDataFiles:
    def test_finds_files_under_jaclang_package(self) -> None:
        import jaclang

        jaclang_root = os.path.dirname(jaclang.__file__)
        files = list(iter_jaclang_data_files())
        assert files, "expected jaclang to ship some .jac/.jir/.lark/.pyi data"

        for abs_path, _rel_dir in files:
            assert abs_path.startswith(jaclang_root), (
                f"data file outside jaclang tree: {abs_path}"
            )
            assert os.path.isfile(abs_path), f"reported file does not exist: {abs_path}"

    def test_emits_pyinstaller_shaped_tuples(self) -> None:
        """Each yielded entry must be a (src, dest_dir) pair where dest_dir
        starts with ``jaclang/`` (the package's parent-relative path)."""
        for abs_path, rel_dir in iter_jaclang_data_files():
            assert os.path.isabs(abs_path), abs_path
            assert not os.path.isabs(rel_dir), rel_dir
            head = rel_dir.split(os.sep, 1)[0]
            assert head == "jaclang", f"unexpected dest root: {rel_dir}"

    def test_includes_bootstrap_modresolver(self) -> None:
        """Sanity: jaclang/jac0core/modresolver.jac is load-bearing for
        frozen-app bootstrap — regressions that drop it would break
        every frozen jac app."""
        paths = [abs_path for abs_path, _ in iter_jaclang_data_files()]
        assert any(
            p.endswith(os.path.join("jac0core", "modresolver.jac")) for p in paths
        )
