"""Tests for jaclang.project.dependencies module."""

from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import patch

import pytest

from jaclang.project.config import JacConfig
from jaclang.project.dependencies import (
    DependencyInstaller,
    DependencyResolver,
    ResolvedDependency,
    add_packages_to_path,
    is_packages_in_path,
    remove_packages_from_path,
)


class TestDependencyInstaller:
    """Tests for the DependencyInstaller class."""

    def test_init_with_config(self, temp_project: Path) -> None:
        """Test initializing installer with config."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        assert installer.config == config
        assert installer.packages_dir == temp_project / "packages"

    def test_init_without_config_fails(self) -> None:
        """Test that init without discoverable config fails."""
        with pytest.raises(ValueError, match="No jac.toml found"):
            DependencyInstaller()

    def test_ensure_packages_dir_creates(self, temp_project: Path) -> None:
        """Test that ensure_packages_dir creates the directory."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        # Remove packages dir if it exists
        packages_dir = temp_project / "packages"
        if packages_dir.exists():
            packages_dir.rmdir()

        installer.ensure_packages_dir()

        assert packages_dir.exists()

    def test_ensure_packages_dir_adds_to_path(self, temp_project: Path) -> None:
        """Test that ensure_packages_dir adds to sys.path."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        packages_str = str(temp_project / "packages")

        # Remove from path if present
        if packages_str in sys.path:
            sys.path.remove(packages_str)

        installer.ensure_packages_dir()

        assert packages_str in sys.path

        # Cleanup
        sys.path.remove(packages_str)

    def test_install_package_success(self, temp_project: Path) -> None:
        """Test successful package installation."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config, verbose=False)

        # Mock pip to avoid actual installation
        with patch.object(installer, "_run_pip") as mock_pip:
            mock_pip.return_value = (0, "Successfully installed", "")

            result = installer.install_package("requests", ">=2.28.0")

            assert result is True
            mock_pip.assert_called_once()
            call_args = mock_pip.call_args[0][0]
            assert "install" in call_args
            assert "--target" in call_args
            assert "requests>=2.28.0" in call_args

    def test_install_package_failure(self, temp_project: Path) -> None:
        """Test failed package installation."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        with patch.object(installer, "_run_pip") as mock_pip:
            mock_pip.return_value = (1, "", "Package not found")

            result = installer.install_package("nonexistent-package")

            assert result is False

    def test_install_package_without_version(self, temp_project: Path) -> None:
        """Test installing package without version constraint."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        with patch.object(installer, "_run_pip") as mock_pip:
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

        with patch.object(installer, "_run_pip") as mock_pip:
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

        with patch.object(installer, "_run_pip") as mock_pip:
            mock_pip.return_value = (0, "", "")

            result = installer.install_all(include_dev=False)

            assert result is True
            # Should install requests (from dependencies)
            assert mock_pip.call_count >= 1

    def test_install_all_with_dev(self, temp_project: Path) -> None:
        """Test installing all dependencies including dev."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        with patch.object(installer, "_run_pip") as mock_pip:
            mock_pip.return_value = (0, "", "")

            result = installer.install_all(include_dev=True)

            assert result is True
            # Should install both requests and pytest
            assert mock_pip.call_count >= 2

    def test_is_installed(self, temp_project: Path) -> None:
        """Test checking if package is installed."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        # Create fake installed package structure
        packages_dir = temp_project / "packages"
        packages_dir.mkdir(exist_ok=True)
        fake_pkg = packages_dir / "requests"
        fake_pkg.mkdir()
        fake_dist_info = packages_dir / "requests-2.28.0.dist-info"
        fake_dist_info.mkdir()

        assert installer.is_installed("requests") is True
        assert installer.is_installed("nonexistent") is False

    def test_list_installed(self, temp_project: Path) -> None:
        """Test listing installed packages."""
        config = JacConfig.load(temp_project / "jac.toml")
        installer = DependencyInstaller(config=config)

        # Create fake dist-info directories
        packages_dir = temp_project / "packages"
        packages_dir.mkdir(exist_ok=True)
        (packages_dir / "requests-2.28.0.dist-info").mkdir()
        (packages_dir / "numpy-1.24.0.dist-info").mkdir()

        installed = installer.list_installed()

        assert "requests" in installed
        assert "numpy" in installed


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

    def test_add_packages_to_path(self, temp_project: Path) -> None:
        """Test adding packages directory to sys.path."""
        config = JacConfig.load(temp_project / "jac.toml")
        packages_dir = temp_project / "packages"
        packages_dir.mkdir(exist_ok=True)

        packages_str = str(packages_dir)
        if packages_str in sys.path:
            sys.path.remove(packages_str)

        add_packages_to_path(config)

        assert packages_str in sys.path

        # Cleanup
        sys.path.remove(packages_str)

    def test_remove_packages_from_path(self, temp_project: Path) -> None:
        """Test removing packages directory from sys.path."""
        config = JacConfig.load(temp_project / "jac.toml")
        packages_dir = temp_project / "packages"
        packages_dir.mkdir(exist_ok=True)

        packages_str = str(packages_dir)
        if packages_str not in sys.path:
            sys.path.insert(0, packages_str)

        remove_packages_from_path(config)

        assert packages_str not in sys.path

    def test_is_packages_in_path(self, temp_project: Path) -> None:
        """Test checking if packages directory is in sys.path."""
        config = JacConfig.load(temp_project / "jac.toml")
        packages_dir = temp_project / "packages"
        packages_dir.mkdir(exist_ok=True)

        packages_str = str(packages_dir)

        # Remove first
        if packages_str in sys.path:
            sys.path.remove(packages_str)

        assert is_packages_in_path(config) is False

        sys.path.insert(0, packages_str)

        assert is_packages_in_path(config) is True

        # Cleanup
        sys.path.remove(packages_str)

    def test_add_packages_no_config(self) -> None:
        """Test add_packages_to_path with no config (no-op)."""
        # Should not raise
        add_packages_to_path(None)

    def test_add_packages_dir_not_exists(self, temp_project: Path) -> None:
        """Test that nonexistent packages dir is not added to path."""
        config = JacConfig.load(temp_project / "jac.toml")

        # Remove packages directory
        packages_dir = temp_project / "packages"
        if packages_dir.exists():
            packages_dir.rmdir()

        packages_str = str(packages_dir)
        if packages_str in sys.path:
            sys.path.remove(packages_str)

        add_packages_to_path(config)

        # Should not be added since dir doesn't exist
        assert packages_str not in sys.path
