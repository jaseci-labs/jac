"""Tests for jaclang.project.dependencies module."""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from jaclang.project.config import JacConfig
from jaclang.project.dependencies import (
    DependencyInstaller,
    DependencyResolver,
    ResolvedDependency,
    add_venv_to_path,
    get_venv_site_packages,
    is_venv_in_path,
    remove_venv_from_path,
)


class TestDependencyInstaller:
    """Tests for the DependencyInstaller class."""

    def test_init_with_config(self, temp_project: Path) -> None:
        """Test initializing installer with config."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        assert installer.config == config
        assert installer.venv_dir == temp_project / ".jac" / "venv"

    def test_init_without_config_fails(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Test that init without discoverable config fails."""
        monkeypatch.chdir(tmp_path)
        with pytest.raises(ValueError, match="No jac.toml found"):
            DependencyInstaller()

    def test_ensure_venv_creates(self, temp_project: Path) -> None:
        """Test that ensure_venv creates the venv directory."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        venv_dir = temp_project / ".jac" / "venv"
        assert not venv_dir.exists()

        with patch("venv.EnvBuilder") as mock_builder_class:
            mock_builder = MagicMock()
            mock_builder_class.return_value = mock_builder

            installer.ensure_venv()

            mock_builder_class.assert_called_once()
            mock_builder.create.assert_called_once_with(str(venv_dir))

    def test_ensure_venv_skips_existing_valid(self, temp_project: Path) -> None:
        """Test that ensure_venv does not recreate a valid venv."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        # Create a fake valid venv structure
        venv_dir = temp_project / ".jac" / "venv"
        venv_dir.mkdir(parents=True, exist_ok=True)
        (venv_dir / "pyvenv.cfg").write_text("home = /usr/bin")
        bin_dir = venv_dir / "bin"
        bin_dir.mkdir(exist_ok=True)
        (bin_dir / "python").write_text("#!/usr/bin/env python")

        with patch("venv.EnvBuilder") as mock_builder_class:
            installer.ensure_venv()
            # Should NOT call create since venv is valid
            mock_builder_class.return_value.create.assert_not_called()

    def test_ensure_venv_recreates_corrupted(self, temp_project: Path) -> None:
        """Test that ensure_venv recreates a corrupted venv."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config, verbose=True)

        # Create a corrupted venv (missing python binary)
        venv_dir = temp_project / ".jac" / "venv"
        venv_dir.mkdir(parents=True, exist_ok=True)
        (venv_dir / "pyvenv.cfg").write_text("home = /usr/bin")
        # Deliberately NOT creating bin/python

        with patch("venv.EnvBuilder") as mock_builder_class:
            mock_builder = MagicMock()
            mock_builder_class.return_value = mock_builder

            installer.ensure_venv()

            # Should recreate since venv is corrupted
            mock_builder.create.assert_called_once_with(str(venv_dir))

    def test_ensure_venv_ensurepip_missing(self, temp_project: Path) -> None:
        """Test that a clear error is raised when ensurepip is not available."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        with patch("venv.EnvBuilder") as mock_builder_class:
            mock_builder = MagicMock()
            mock_builder.create.side_effect = Exception("No module named 'ensurepip'")
            mock_builder_class.return_value = mock_builder

            with pytest.raises(RuntimeError, match="sudo apt install python3-venv"):
                installer.ensure_venv()

    def test_install_package_success(self, temp_project: Path) -> None:
        """Test successful package installation."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config, verbose=False)

        with (
            patch.object(installer, "ensure_venv"),
            patch.object(installer, "_run_pip") as mock_pip,
        ):
            mock_pip.return_value = (0, "Successfully installed", "")

            result = installer.install_package(["requests>=2.28.0"])

            assert result is True
            mock_pip.assert_called_once()
            call_args = mock_pip.call_args[0][0]
            assert "install" in call_args
            assert "--upgrade" in call_args
            assert "requests>=2.28.0" in call_args
            # Should NOT use --target
            assert "--target" not in call_args

    def test_install_package_failure(self, temp_project: Path) -> None:
        """Test failed package installation."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        with (
            patch.object(installer, "ensure_venv"),
            patch.object(installer, "_run_pip") as mock_pip,
        ):
            mock_pip.return_value = (1, "", "Package not found")

            result = installer.install_package(["nonexistent-package"])

            assert result is False

    def test_install_package_without_version(self, temp_project: Path) -> None:
        """Test installing package without version constraint."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        with (
            patch.object(installer, "ensure_venv"),
            patch.object(installer, "_run_pip") as mock_pip,
        ):
            mock_pip.return_value = (0, "", "")

            installer.install_package(["requests"])

            call_args = mock_pip.call_args[0][0]
            assert "requests" in call_args
            # Should not have version spec
            assert not any("requests==" in arg for arg in call_args)

    def test_install_git_package(self, temp_project: Path) -> None:
        """Test installing git-based package."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        with (
            patch.object(installer, "ensure_venv"),
            patch.object(installer, "_run_pip") as mock_pip,
        ):
            mock_pip.return_value = (0, "", "")

            specs = installer._make_git_spec(
                "my-plugin", "https://github.com/user/plugin.git", branch="main"
            )
            result = installer.install_package([specs])

            assert result is True
            call_args = mock_pip.call_args[0][0]
            assert "git+https://github.com/user/plugin.git@main" in call_args

    def test_install_all(self, temp_project: Path) -> None:
        """Test installing all dependencies with batch resolution."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        with (
            patch.object(installer, "ensure_venv"),
            patch.object(installer, "_run_pip") as mock_pip,
        ):
            mock_pip.return_value = (0, "", "")
            pip_packages = installer.get_pip_package_specs(include_dev=False)
            git_packages = installer.get_git_package_specs()
            result = installer.install_package(pip_packages + git_packages)

            assert result is True
            # Single batch call for all Python packages
            assert mock_pip.call_count == 1

    def test_install_all_with_dev(self, temp_project: Path) -> None:
        """Test installing all dependencies including dev with batch resolution."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        with (
            patch.object(installer, "ensure_venv"),
            patch.object(installer, "_run_pip") as mock_pip,
        ):
            mock_pip.return_value = (0, "", "")
            pip_packages = installer.get_pip_package_specs(include_dev=True)
            git_packages = installer.get_git_package_specs()
            result = installer.install_package(pip_packages + git_packages)

            assert result is True
            # Single batch call with both regular and dev dependencies
            assert mock_pip.call_count == 1

    def test_is_installed(self, temp_project: Path) -> None:
        """Test checking if package is installed."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        # Create a fake venv dir so the check doesn't short-circuit
        venv_dir = temp_project / ".jac" / "venv"
        venv_dir.mkdir(parents=True, exist_ok=True)

        with patch.object(installer, "_run_pip") as mock_pip:
            # Simulate installed package
            mock_pip.return_value = (0, "Name: requests\nVersion: 2.28.0", "")
            assert installer.is_installed("requests") is True
            mock_pip.assert_called_with(["show", "requests"])

            # Simulate not installed
            mock_pip.return_value = (
                1,
                "",
                "WARNING: Package(s) not found: nonexistent",
            )
            assert installer.is_installed("nonexistent") is False

    def test_get_installed_version(self, temp_project: Path) -> None:
        """Test getting installed version of a package."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        venv_dir = temp_project / ".jac" / "venv"
        venv_dir.mkdir(parents=True, exist_ok=True)

        with patch.object(installer, "_run_pip") as mock_pip:
            mock_pip.return_value = (
                0,
                "Name: requests\nVersion: 2.31.0\nSummary: HTTP library",
                "",
            )
            version = installer.get_installed_version("requests")
            assert version == "2.31.0"
            mock_pip.assert_called_with(["show", "requests"])

    def test_get_installed_version_not_found(self, temp_project: Path) -> None:
        """Test getting version of non-installed package returns None."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        venv_dir = temp_project / ".jac" / "venv"
        venv_dir.mkdir(parents=True, exist_ok=True)

        with patch.object(installer, "_run_pip") as mock_pip:
            mock_pip.return_value = (
                1,
                "",
                "WARNING: Package(s) not found: nonexistent",
            )
            version = installer.get_installed_version("nonexistent")
            assert version is None

    def test_get_installed_version_no_venv(self, temp_project: Path) -> None:
        """Test getting version without venv returns None."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)
        # Don't create venv dir
        version = installer.get_installed_version("requests")
        assert version is None

    def test_list_installed(self, temp_project: Path) -> None:
        """Test listing installed packages."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        # Create a fake venv dir
        venv_dir = temp_project / ".jac" / "venv"
        venv_dir.mkdir(parents=True, exist_ok=True)

        with patch.object(installer, "_run_pip") as mock_pip:
            mock_pip.return_value = (
                0,
                '[{"name":"requests","version":"2.28.0"},'
                '{"name":"numpy","version":"1.24.0"},'
                '{"name":"pip","version":"23.0"},'
                '{"name":"setuptools","version":"67.0"}]',
                "",
            )

            installed = installer.list_installed()

            assert "requests" in installed
            assert "numpy" in installed
            # Infrastructure packages should be filtered out
            assert "pip" not in installed
            assert "setuptools" not in installed
            mock_pip.assert_called_with(["list", "--format=json"])

    def test_uninstall_package(self, temp_project: Path) -> None:
        """Test uninstalling a package via pip uninstall."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config, verbose=True)

        # Create a fake venv dir
        venv_dir = temp_project / ".jac" / "venv"
        venv_dir.mkdir(parents=True, exist_ok=True)

        with patch.object(installer, "_run_pip") as mock_pip:
            mock_pip.return_value = (0, "Successfully uninstalled testpkg-1.0.0", "")
            result = installer.uninstall_package("testpkg")

            assert result is True
            mock_pip.assert_called_once_with(["uninstall", "-y", "testpkg"])

    def test_uninstall_package_not_installed(self, temp_project: Path) -> None:
        """Test uninstalling a package that is not installed."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        # Create a fake venv dir
        venv_dir = temp_project / ".jac" / "venv"
        venv_dir.mkdir(parents=True, exist_ok=True)

        with patch.object(installer, "_run_pip") as mock_pip:
            mock_pip.return_value = (
                1,
                "",
                "WARNING: Skipping testpkg as it is not installed.",
            )
            result = installer.uninstall_package("testpkg")

            assert result is False

    def test_uninstall_package_no_venv(self, temp_project: Path) -> None:
        """Test uninstalling when no venv exists."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        result = installer.uninstall_package("testpkg")

        assert result is False


class TestDependencyResolver:
    """Tests for the DependencyResolver class."""

    def test_parse_spec_with_version(self) -> None:
        """Test parsing dependency spec with version."""
        config = JacConfig()
        config.project_root = Path("/tmp")
        resolver = DependencyResolver(config=config)

        name, version = resolver.parse_spec("requests>=2.28.0")

        assert name == "requests"
        assert version == ">=2.28.0"

    def test_parse_spec_without_version(self) -> None:
        """Test parsing dependency spec without version."""
        config = JacConfig()
        config.project_root = Path("/tmp")
        resolver = DependencyResolver(config=config)

        name, version = resolver.parse_spec("requests")

        assert name == "requests"
        assert version == ""

    def test_parse_spec_with_equals(self) -> None:
        """Test parsing dependency spec with ==."""
        config = JacConfig()
        config.project_root = Path("/tmp")
        resolver = DependencyResolver(config=config)

        name, version = resolver.parse_spec("numpy==1.24.0")

        assert name == "numpy"
        assert version == "==1.24.0"

    def test_parse_spec_with_tilde(self) -> None:
        """Test parsing dependency spec with ~=."""
        config = JacConfig()
        config.project_root = Path("/tmp")
        resolver = DependencyResolver(config=config)

        name, version = resolver.parse_spec("django~=4.0")

        assert name == "django"
        assert version == "~=4.0"

    def test_resolve_dependencies(self, temp_project: Path) -> None:
        """Test resolving all dependencies."""
        config = JacConfig.load(temp_project / "jac.toml")
        resolver = DependencyResolver(config=config)

        resolved = resolver.resolve(include_dev=False)

        assert len(resolved) >= 1
        names = [r.name for r in resolved]
        assert "requests" in names

    def test_resolve_with_dev(self, temp_project: Path) -> None:
        """Test resolving with dev dependencies."""
        config = JacConfig.load(temp_project / "jac.toml")
        resolver = DependencyResolver(config=config)

        resolved = resolver.resolve(include_dev=True)

        names = [r.name for r in resolved]
        assert "requests" in names
        assert "pytest" in names


class TestResolvedDependency:
    """Tests for ResolvedDependency dataclass."""

    def test_create_resolved_dependency(self) -> None:
        """Test creating a ResolvedDependency."""
        dep = ResolvedDependency(
            name="requests",
            version=">=2.28.0",
            source="pypi",
        )

        assert dep.name == "requests"
        assert dep.version == ">=2.28.0"
        assert dep.source == "pypi"
        assert dep.extras == []
        assert dep.dependencies == []

    def test_resolved_dependency_with_extras(self) -> None:
        """Test ResolvedDependency with extras and dependencies."""
        dep = ResolvedDependency(
            name="requests",
            version="2.28.0",
            source="pypi",
            extras=["security"],
            dependencies=["urllib3", "certifi"],
        )

        assert dep.extras == ["security"]
        assert dep.dependencies == ["urllib3", "certifi"]


class TestPathManagement:
    """Tests for sys.path management functions."""

    def test_add_venv_to_path(self, temp_project: Path) -> None:
        """Test adding venv site-packages to sys.path."""
        config = JacConfig.load(temp_project / "jac.toml")
        site_packages = get_venv_site_packages(config.get_venv_dir())
        site_packages.mkdir(parents=True, exist_ok=True)

        site_str = str(site_packages)
        if site_str in sys.path:
            sys.path.remove(site_str)

        add_venv_to_path(config)

        assert site_str in sys.path

        # Cleanup
        sys.path.remove(site_str)

    def test_remove_venv_from_path(self, temp_project: Path) -> None:
        """Test removing venv site-packages from sys.path."""
        config = JacConfig.load(temp_project / "jac.toml")
        site_packages = get_venv_site_packages(config.get_venv_dir())
        site_packages.mkdir(parents=True, exist_ok=True)

        site_str = str(site_packages)
        if site_str not in sys.path:
            sys.path.insert(0, site_str)

        remove_venv_from_path(config)

        assert site_str not in sys.path

    def test_is_venv_in_path(self, temp_project: Path) -> None:
        """Test checking if venv site-packages is in sys.path."""
        config = JacConfig.load(temp_project / "jac.toml")
        site_packages = get_venv_site_packages(config.get_venv_dir())
        site_packages.mkdir(parents=True, exist_ok=True)

        site_str = str(site_packages)

        # Remove first
        if site_str in sys.path:
            sys.path.remove(site_str)

        assert is_venv_in_path(config) is False

        sys.path.insert(0, site_str)

        assert is_venv_in_path(config) is True

        # Cleanup
        sys.path.remove(site_str)

    def test_add_venv_no_config(self) -> None:
        """Test add_venv_to_path with no config (no-op)."""
        # Should not raise
        add_venv_to_path(None)

    def test_add_venv_dir_not_exists(self, temp_project: Path) -> None:
        """Test that nonexistent site-packages dir is not added to path."""
        config = JacConfig.load(temp_project / "jac.toml")

        site_packages = get_venv_site_packages(config.get_venv_dir())
        site_str = str(site_packages)
        if site_str in sys.path:
            sys.path.remove(site_str)

        add_venv_to_path(config)

        # Should not be added since dir doesn't exist
        assert site_str not in sys.path


class TestProjectCommands:
    """Tests for CLI project commands (install, add, update)."""

    @staticmethod
    def _create_project(tmpdir: str, toml_content: str | None = None) -> str:
        """Create a minimal jac project for testing."""
        project_path = os.path.join(tmpdir, "testproj")
        os.makedirs(project_path, exist_ok=True)
        if toml_content is None:
            toml_content = """\
[project]
name = "testproj"
version = "0.1.0"

[dependencies]
requests = ">=2.28.0"
flask = "~=3.0"

[dev-dependencies]
pytest = ">=8.0.0"
"""
        with open(os.path.join(project_path, "jac.toml"), "w") as f:
            f.write(toml_content)
        return project_path

    @staticmethod
    def _reset_config() -> None:
        """Reset global config singleton."""
        from jaclang.project import config as config_module

        config_module._config = None

    def test_install_with_pip_and_git_deps(self) -> None:
        """Test jac install installs both pip and git dependencies."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            toml = """\
[project]
name = "testproj"
version = "0.1.0"

[dependencies]
requests = ">=2.28.0"

[dependencies.git]
my-lib = {git = "https://github.com/user/my-lib.git", branch = "main"}
"""
            project_path = self._create_project(tmpdir, toml)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    mock_pip.return_value = (
                        0,
                        "Successfully installed requests-2.31.0",
                        "",
                    )
                    result = project.install()
                assert result == 0
                # Should have called pip install with both pip and git specs
                mock_pip.assert_called()
                call_args = mock_pip.call_args[0][0]
                assert "install" in call_args
                assert "--upgrade" in call_args
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_install_pip_and_npm_deps(self) -> None:
        """Test jac install handles both pypi and npm dependencies together."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            toml = """\
[project]
name = "fullstack"
version = "0.1.0"

[dependencies]
requests = "~=2.31"
flask = "~=3.0"

[dependencies.npm]
react = "^18.0.0"
typescript = "^5.0.0"

[dev-dependencies]
pytest = ">=8.0.0"
"""
            project_path = self._create_project(tmpdir, toml)
            os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                mock_install_all = MagicMock()
                mock_dep_type = MagicMock()
                mock_dep_type.install_all_handler = mock_install_all
                mock_dep_type.install_handler = MagicMock()

                mock_registry = MagicMock()
                mock_registry.get_all.return_value = {"npm": mock_dep_type}

                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                    patch(
                        "jaclang.project.dep_registry.get_dependency_registry",
                        return_value=mock_registry,
                    ),
                ):
                    mock_pip.return_value = (
                        0,
                        "Successfully installed requests-2.31.0 flask-3.0.0",
                        "",
                    )
                    result = project.install()

                assert result == 0
                # Verify pip packages were installed
                mock_pip.assert_called()
                pip_call_args = mock_pip.call_args[0][0]
                assert "install" in pip_call_args
                assert "--upgrade" in pip_call_args
                # Verify npm install_all_handler was also called
                mock_install_all.assert_called_once()
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_install_with_plugin_deps(self) -> None:
        """Test jac install calls plugin install_all_handler for plugin deps."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            toml = """\
[project]
name = "testproj"
version = "0.1.0"

[dependencies]

[dependencies.npm]
react = "18.0"
"""
            project_path = self._create_project(tmpdir, toml)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                mock_install_all = MagicMock()
                mock_dep_type = MagicMock()
                mock_dep_type.install_all_handler = mock_install_all
                mock_dep_type.install_handler = MagicMock()

                mock_registry = MagicMock()
                mock_registry.get_all.return_value = {"npm": mock_dep_type}

                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                    patch(
                        "jaclang.project.dep_registry.get_dependency_registry",
                        return_value=mock_registry,
                    ),
                ):
                    mock_pip.return_value = (0, "", "")
                    result = project.install()

                assert result == 0
                mock_install_all.assert_called_once()
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_install_plugin_deps_individual_fallback(self) -> None:
        """Test jac install calls individual install_handler when no install_all_handler."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            toml = """\
[project]
name = "testproj"
version = "0.1.0"

[dependencies]

[dependencies.npm]
react = "18.0"
vue = "3.0"
"""
            project_path = self._create_project(tmpdir, toml)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                mock_install_handler = MagicMock()
                mock_dep_type = MagicMock()
                mock_dep_type.install_all_handler = None
                mock_dep_type.install_handler = mock_install_handler

                mock_registry = MagicMock()
                mock_registry.get_all.return_value = {"npm": mock_dep_type}

                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                    patch(
                        "jaclang.project.dep_registry.get_dependency_registry",
                        return_value=mock_registry,
                    ),
                ):
                    mock_pip.return_value = (0, "", "")
                    result = project.install()

                assert result == 0
                # Should have called install_handler for each npm dep
                assert mock_install_handler.call_count == 2
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_install_no_toml(self) -> None:
        """Test jac install fails when no jac.toml exists."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            original_cwd = os.getcwd()
            os.chdir(tmpdir)
            self._reset_config()
            try:
                result = project.install()
                assert result == 1
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_add_no_args_errors(self) -> None:
        """Test jac add with no arguments returns error."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                result = project.add()
                assert result == 1
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_add_no_toml_errors(self) -> None:
        """Test jac add fails when no jac.toml exists."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            original_cwd = os.getcwd()
            os.chdir(tmpdir)
            self._reset_config()
            try:
                result = project.add(packages=["requests"])
                assert result == 1
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_add_resolves_version(self) -> None:
        """Test jac add without version queries installed version and uses ~= spec."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            # Create fake venv so get_installed_version doesn't short-circuit
            venv_dir = os.path.join(project_path, ".jac", "venv")
            os.makedirs(venv_dir, exist_ok=True)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    # First call: pip install numpy (install the package)
                    # Second call: pip show numpy (get installed version)
                    mock_pip.side_effect = [
                        (0, "Successfully installed numpy-1.26.4", ""),
                        (0, "Name: numpy\nVersion: 1.26.4\nSummary: ...", ""),
                    ]
                    result = project.add(packages=["numpy"])

                assert result == 0
                # Verify jac.toml was updated with ~= version
                config = JacConfig.load(Path(project_path) / "jac.toml")
                assert "numpy" in config.dependencies
                assert config.dependencies["numpy"] == "~=1.26"
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_add_with_explicit_version(self) -> None:
        """Test jac add with explicit version uses that version directly."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    mock_pip.return_value = (
                        0,
                        "Successfully installed numpy-1.24.0",
                        "",
                    )
                    result = project.add(packages=["numpy>=1.24"])

                assert result == 0
                config = JacConfig.load(Path(project_path) / "jac.toml")
                assert "numpy" in config.dependencies
                assert config.dependencies["numpy"] == ">=1.24"
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_update_all_deps(self) -> None:
        """Test jac update updates ~= specs and preserves explicit specs."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    # install_package call, then pip show for each package
                    mock_pip.side_effect = [
                        (0, "Successfully installed requests-2.31.0 flask-3.1.0", ""),
                        (0, "Name: requests\nVersion: 2.31.0", ""),
                        (0, "Name: flask\nVersion: 3.1.0", ""),
                    ]
                    result = project.update()

                assert result == 0
                config = JacConfig.load(Path(project_path) / "jac.toml")
                # requests uses >=2.28.0 (explicit) -> preserved unchanged
                assert config.dependencies["requests"] == ">=2.28.0"
                # flask uses ~=3.0 (auto-generated) -> updated to ~=3.1
                assert config.dependencies["flask"] == "~=3.1"
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_update_specific_package(self) -> None:
        """Test jac update with specific package updates ~= spec."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            # Use toml with ~= specs so update can rewrite them
            toml = """\
[project]
name = "testproj"
version = "0.1.0"

[dependencies]
requests = "~=2.28"
flask = "~=3.0"

[dev-dependencies]
pytest = ">=8.0.0"
"""
            project_path = self._create_project(tmpdir, toml)
            os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    mock_pip.side_effect = [
                        (0, "Successfully installed requests-2.32.0", ""),
                        (0, "Name: requests\nVersion: 2.32.0", ""),
                    ]
                    result = project.update(packages=["requests"])

                assert result == 0
                config = JacConfig.load(Path(project_path) / "jac.toml")
                assert config.dependencies["requests"] == "~=2.32"
                # flask should be unchanged
                assert config.dependencies["flask"] == "~=3.0"
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_update_unknown_package_errors(self) -> None:
        """Test jac update with unknown package returns error."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                result = project.update(packages=["nonexistent"])
                assert result == 1
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_update_no_toml_errors(self) -> None:
        """Test jac update fails when no jac.toml exists."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            original_cwd = os.getcwd()
            os.chdir(tmpdir)
            self._reset_config()
            try:
                result = project.update()
                assert result == 1
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_add_dev_dependency(self) -> None:
        """Test jac add --dev puts package in dev-dependencies."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    mock_pip.side_effect = [
                        (0, "Successfully installed pytest-cov-7.0.0", ""),
                        (0, "Name: pytest-cov\nVersion: 7.0.0", ""),
                    ]
                    result = project.add(packages=["pytest-cov"], dev=True)

                assert result == 0
                config = JacConfig.load(Path(project_path) / "jac.toml")
                assert "pytest-cov" in config.dev_dependencies
                assert config.dev_dependencies["pytest-cov"] == "~=7.0"
                # Should NOT be in regular dependencies
                assert "pytest-cov" not in config.dependencies
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_add_multiple_packages(self) -> None:
        """Test jac add with multiple packages installs all and updates toml."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    mock_pip.side_effect = [
                        (0, "Successfully installed numpy-2.4.2", ""),
                        (0, "Name: numpy\nVersion: 2.4.2", ""),
                        (0, "Successfully installed pandas-3.0.0", ""),
                        (0, "Name: pandas\nVersion: 3.0.0", ""),
                    ]
                    result = project.add(packages=["numpy", "pandas"])

                assert result == 0
                config = JacConfig.load(Path(project_path) / "jac.toml")
                assert config.dependencies["numpy"] == "~=2.4"
                assert config.dependencies["pandas"] == "~=3.0"
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_add_pip_failure_no_toml_update(self) -> None:
        """Test that pip failure does not modify jac.toml."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            # Read original toml content
            toml_path = os.path.join(project_path, "jac.toml")
            with open(toml_path) as f:
                original_toml = f.read()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    mock_pip.return_value = (
                        1,
                        "",
                        "ERROR: No matching distribution found for badpkg",
                    )
                    result = project.add(packages=["badpkg"])

                assert result == 1
                # jac.toml should be unchanged
                with open(toml_path) as f:
                    assert f.read() == original_toml
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_add_git_dependency(self) -> None:
        """Test jac add --git adds a git dependency and persists to toml."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    mock_pip.return_value = (0, "Successfully installed my-lib", "")
                    result = project.add(git="https://github.com/user/my-lib.git")

                assert result == 0
                # Verify saved toml has the git dependency
                config = JacConfig.load(Path(project_path) / "jac.toml")
                assert "my-lib" in config.git_dependencies
                assert (
                    config.git_dependencies["my-lib"]["git"]
                    == "https://github.com/user/my-lib.git"
                )
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_update_with_dev_deps(self) -> None:
        """Test jac update --dev includes dev dependencies in update."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            # Use ~= specs so update can rewrite them
            toml = """\
[project]
name = "testproj"
version = "0.1.0"

[dependencies]
requests = "~=2.28"
flask = "~=3.0"

[dev-dependencies]
pytest = "~=8.0"
"""
            project_path = self._create_project(tmpdir, toml)
            os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    # install_package, then pip show for requests, flask, pytest
                    mock_pip.side_effect = [
                        (0, "Successfully installed", ""),
                        (0, "Name: requests\nVersion: 2.32.0", ""),
                        (0, "Name: flask\nVersion: 3.1.0", ""),
                        (0, "Name: pytest\nVersion: 8.3.0", ""),
                    ]
                    result = project.update(dev=True)

                assert result == 0
                config = JacConfig.load(Path(project_path) / "jac.toml")
                assert config.dependencies["requests"] == "~=2.32"
                assert config.dependencies["flask"] == "~=3.1"
                # Dev dep should also be updated
                assert config.dev_dependencies["pytest"] == "~=8.3"
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_install_empty_deps(self) -> None:
        """Test jac install with no dependencies returns 0 with info message."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            toml = """\
[project]
name = "empty"
version = "0.1.0"

[dependencies]

[dev-dependencies]
"""
            project_path = self._create_project(tmpdir, toml)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                result = project.install()
                assert result == 0
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_remove_package(self) -> None:
        """Test jac remove removes package from toml and uninstalls."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    mock_pip.return_value = (
                        0,
                        "Successfully uninstalled requests-2.31.0",
                        "",
                    )
                    result = project.remove(packages=["requests"])

                assert result == 0
                # Verify saved toml no longer has requests
                config = JacConfig.load(Path(project_path) / "jac.toml")
                assert "requests" not in config.dependencies
                # flask should still be there
                assert "flask" in config.dependencies
                # Verify pip uninstall was called
                mock_pip.assert_called_with(["uninstall", "-y", "requests"])
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_remove_dev_dep_without_flag(self) -> None:
        """Test jac remove finds dev deps even without --dev flag."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            os.makedirs(os.path.join(project_path, ".jac", "venv"), exist_ok=True)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                with (
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller.ensure_venv"
                    ),
                    patch(
                        "jaclang.project.dependencies.DependencyInstaller._run_pip"
                    ) as mock_pip,
                ):
                    mock_pip.return_value = (
                        0,
                        "Successfully uninstalled pytest-8.0.0",
                        "",
                    )
                    # pytest is in dev-dependencies, but we don't pass --dev
                    result = project.remove(packages=["pytest"])

                assert result == 0
                config = JacConfig.load(Path(project_path) / "jac.toml")
                # pytest should be removed from dev-dependencies
                assert "pytest" not in config.dev_dependencies
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_remove_no_args_errors(self) -> None:
        """Test jac remove with no arguments returns error."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                result = project.remove()
                assert result == 1
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_remove_no_toml_errors(self) -> None:
        """Test jac remove fails when no jac.toml exists."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            original_cwd = os.getcwd()
            os.chdir(tmpdir)
            self._reset_config()
            try:
                result = project.remove(packages=["requests"])
                assert result == 1
            finally:
                os.chdir(original_cwd)
                self._reset_config()

    def test_remove_nonexistent_package(self) -> None:
        """Test jac remove with package not in toml still returns 0."""
        from jaclang.cli.commands import project  # type: ignore[attr-defined]

        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = self._create_project(tmpdir)
            original_cwd = os.getcwd()
            os.chdir(project_path)
            self._reset_config()
            try:
                result = project.remove(packages=["nonexistent"])
                # remove returns 0 even if package wasn't found (just prints error)
                assert result == 0
            finally:
                os.chdir(original_cwd)
                self._reset_config()
