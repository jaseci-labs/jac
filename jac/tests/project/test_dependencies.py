"""Tests for jaclang.project.dependencies module."""

from __future__ import annotations

import sys
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

            result = installer.install_package("requests", ">=2.28.0")

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

            result = installer.install_package("nonexistent-package")

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

            installer.install_package("requests")

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

            result = installer.install_git_package(
                "my-plugin", "https://github.com/user/plugin.git", branch="main"
            )

            assert result is True
            call_args = mock_pip.call_args[0][0]
            assert "git+https://github.com/user/plugin.git@main" in call_args

    def test_install_all(self, temp_project: Path) -> None:
        """Test installing all dependencies."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        with (
            patch.object(installer, "ensure_venv"),
            patch.object(installer, "_run_pip") as mock_pip,
        ):
            mock_pip.return_value = (0, "", "")

            result = installer.install_all(include_dev=False)

            assert result is True
            # Should install requests (from dependencies)
            assert mock_pip.call_count >= 1

    def test_install_all_with_dev(self, temp_project: Path) -> None:
        """Test installing all dependencies including dev."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        with (
            patch.object(installer, "ensure_venv"),
            patch.object(installer, "_run_pip") as mock_pip,
        ):
            mock_pip.return_value = (0, "", "")

            result = installer.install_all(include_dev=True)

            assert result is True
            # Should install both requests and pytest
            assert mock_pip.call_count >= 2

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
