"""Tests for jaclang.project.config module."""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from jaclang.project.config import (
    JacConfig,
    find_project_root,
    get_config,
    interpolate_env_vars,
    is_in_project,
    set_config,
)


class TestInterpolateEnvVars:
    """Tests for environment variable interpolation."""

    def test_simple_env_var(self) -> None:
        """Test simple environment variable substitution."""
        os.environ["TEST_VAR"] = "hello"
        result = interpolate_env_vars("prefix-${TEST_VAR}-suffix")
        assert result == "prefix-hello-suffix"
        del os.environ["TEST_VAR"]

    def test_env_var_with_default(self) -> None:
        """Test environment variable with default value."""
        # Ensure var doesn't exist
        os.environ.pop("NONEXISTENT_VAR", None)
        result = interpolate_env_vars("${NONEXISTENT_VAR:-default_value}")
        assert result == "default_value"

    def test_env_var_with_default_when_set(self) -> None:
        """Test that set env var overrides default."""
        os.environ["MY_VAR"] = "actual"
        result = interpolate_env_vars("${MY_VAR:-default}")
        assert result == "actual"
        del os.environ["MY_VAR"]

    def test_required_env_var_missing(self) -> None:
        """Test that missing required env var raises error."""
        os.environ.pop("REQUIRED_VAR", None)
        with pytest.raises(ValueError, match="REQUIRED_VAR is not set"):
            interpolate_env_vars("${REQUIRED_VAR}")

    def test_required_env_var_with_custom_error(self) -> None:
        """Test required env var with custom error message."""
        os.environ.pop("MY_SECRET", None)
        with pytest.raises(ValueError, match="Secret must be configured"):
            interpolate_env_vars("${MY_SECRET:?Secret must be configured}")

    def test_multiple_env_vars(self) -> None:
        """Test multiple env vars in one string."""
        os.environ["HOST"] = "localhost"
        os.environ["PORT"] = "8080"
        result = interpolate_env_vars("http://${HOST}:${PORT}/api")
        assert result == "http://localhost:8080/api"
        del os.environ["HOST"]
        del os.environ["PORT"]

    def test_non_string_passthrough(self) -> None:
        """Test that non-strings pass through unchanged."""
        assert interpolate_env_vars(123) == 123  # type: ignore
        assert interpolate_env_vars(None) is None  # type: ignore


class TestFindProjectRoot:
    """Tests for project root discovery."""

    def test_find_project_in_current_dir(self, temp_project: Path) -> None:
        """Test finding jac.toml in current directory."""
        result = find_project_root(temp_project)
        assert result is not None
        project_root, toml_path = result
        # Resolve both paths to handle symlinks (e.g., /var -> /private/var on macOS)
        assert project_root.resolve() == temp_project.resolve()
        assert toml_path.resolve() == (temp_project / "jac.toml").resolve()

    def test_find_project_in_parent_dir(self, temp_project: Path) -> None:
        """Test finding jac.toml in parent directory."""
        subdir = temp_project / "src" / "submodule"
        subdir.mkdir(parents=True)

        result = find_project_root(subdir)
        assert result is not None
        project_root, toml_path = result
        # Resolve both paths to handle symlinks (e.g., /var -> /private/var on macOS)
        assert project_root.resolve() == temp_project.resolve()
        assert toml_path.resolve() == (temp_project / "jac.toml").resolve()

    def test_no_project_found(self, temp_dir: Path) -> None:
        """Test when no jac.toml exists."""
        empty_dir = temp_dir / "empty"
        empty_dir.mkdir()

        result = find_project_root(empty_dir)
        assert result is None

    def test_is_in_project(self, temp_project: Path) -> None:
        """Test is_in_project helper."""
        # Save current dir
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_project)
            assert is_in_project() is True

            os.chdir(temp_project.parent)
            # Parent has no jac.toml (temp_dir)
            assert is_in_project() is False
        finally:
            os.chdir(original_cwd)


class TestJacConfigLoad:
    """Tests for loading JacConfig from files."""

    def test_load_basic_config(self, temp_project: Path) -> None:
        """Test loading a basic jac.toml config."""
        config = JacConfig.load(temp_project / "jac.toml")

        assert config.project.name == "test-project"
        assert config.project.version == "0.1.0"
        assert config.project.description == "A test project"
        assert config.project.entry_point == "main.jac"

    def test_load_dependencies(self, temp_project: Path) -> None:
        """Test loading dependencies from config."""
        config = JacConfig.load(temp_project / "jac.toml")

        assert "requests" in config.dependencies
        assert config.dependencies["requests"] == ">=2.28.0"

    def test_load_dev_dependencies(self, temp_project: Path) -> None:
        """Test loading dev dependencies from config."""
        config = JacConfig.load(temp_project / "jac.toml")

        assert "pytest" in config.dev_dependencies
        assert config.dev_dependencies["pytest"] == ">=8.0.0"

    def test_load_run_config(self, temp_project: Path) -> None:
        """Test loading run command config."""
        config = JacConfig.load(temp_project / "jac.toml")

        assert config.run.main is True
        assert config.run.cache is True

    def test_load_scripts(self, temp_project: Path) -> None:
        """Test loading scripts section."""
        config = JacConfig.load(temp_project / "jac.toml")

        assert "test" in config.scripts
        assert config.scripts["test"] == "jac test"

    def test_load_nonexistent_file(self, temp_dir: Path) -> None:
        """Test loading nonexistent file raises error."""
        with pytest.raises(FileNotFoundError):
            JacConfig.load(temp_dir / "nonexistent.toml")

    def test_project_root_set(self, temp_project: Path) -> None:
        """Test that project_root is set after loading."""
        config = JacConfig.load(temp_project / "jac.toml")

        assert config.project_root == temp_project
        assert config.toml_path == temp_project / "jac.toml"


class TestJacConfigDiscover:
    """Tests for auto-discovery of JacConfig."""

    def test_discover_from_project_root(self, temp_project: Path) -> None:
        """Test discovering config from project root."""
        config = JacConfig.discover(temp_project)

        assert config is not None
        assert config.project.name == "test-project"

    def test_discover_from_subdirectory(self, temp_project: Path) -> None:
        """Test discovering config from subdirectory."""
        subdir = temp_project / "src"
        config = JacConfig.discover(subdir)

        assert config is not None
        assert config.project.name == "test-project"

    def test_discover_no_project(self, temp_dir: Path) -> None:
        """Test discovering returns None when no project."""
        config = JacConfig.discover(temp_dir)
        assert config is None


class TestJacConfigFromTomlStr:
    """Tests for parsing TOML strings."""

    def test_parse_minimal_config(self) -> None:
        """Test parsing minimal TOML string."""
        toml_str = """
[project]
name = "minimal"
"""
        config = JacConfig.from_toml_str(toml_str)

        assert config.project.name == "minimal"
        assert config.project.version == "0.1.0"  # default

    def test_parse_full_config(self) -> None:
        """Test parsing full TOML configuration."""
        toml_str = """
[project]
name = "full-project"
version = "1.2.3"
description = "A full project"
authors = ["Jane Doe <jane@example.com>"]
license = "MIT"
entry-point = "app.jac"

[dependencies]
numpy = ">=1.24.0"
pandas = ">=2.0.0"

[run]
session = "my_session"
main = false
cache = false

[build]
typecheck = true

[test]
directory = "tests"
verbose = true
fail_fast = true
max_failures = 5

[serve]
port = 9000

[cache]
enabled = false
dir = ".cache"

[scripts]
start = "jac run app.jac"
lint = "jac format . --fix"

[plugins.byllm]
default_model = "gpt-4"
temperature = 0.7

[environments.development]
[environments.development.serve]
port = 3000

[environments.production]
[environments.production.serve]
port = 8000
"""
        config = JacConfig.from_toml_str(toml_str)

        # Project
        assert config.project.name == "full-project"
        assert config.project.version == "1.2.3"
        assert config.project.description == "A full project"
        assert config.project.license == "MIT"
        assert config.project.entry_point == "app.jac"

        # Dependencies
        assert "numpy" in config.dependencies
        assert "pandas" in config.dependencies

        # Run config
        assert config.run.session == "my_session"
        assert config.run.main is False
        assert config.run.cache is False

        # Build config
        assert config.build.typecheck is True

        # Test config
        assert config.test.directory == "tests"
        assert config.test.verbose is True
        assert config.test.fail_fast is True
        assert config.test.max_failures == 5

        # Serve config
        assert config.serve.port == 9000

        # Cache config
        assert config.cache.enabled is False
        assert config.cache.dir == ".cache"

        # Scripts
        assert config.scripts["start"] == "jac run app.jac"
        assert config.scripts["lint"] == "jac format . --fix"

        # Plugin config
        assert "byllm" in config.plugins
        assert config.plugins["byllm"]["default_model"] == "gpt-4"

        # Environments
        assert "development" in config.environments
        assert "production" in config.environments


class TestJacConfigProfiles:
    """Tests for environment profiles."""

    def test_apply_profile(self) -> None:
        """Test applying an environment profile."""
        toml_str = """
[project]
name = "profile-test"

[serve]
port = 8000

[environments.development]
[environments.development.serve]
port = 3000
"""
        config = JacConfig.from_toml_str(toml_str)

        assert config.serve.port == 8000

        config.apply_profile("development")

        assert config.serve.port == 3000

    def test_profile_inheritance(self) -> None:
        """Test profile inheritance with 'inherits' key."""
        toml_str = """
[project]
name = "inherit-test"

[serve]
port = 8000

[environments.base]
[environments.base.serve]
port = 9000

[environments.staging]
inherits = "base"

[environments.staging.test]
verbose = true
"""
        config = JacConfig.from_toml_str(toml_str)

        config.apply_profile("staging")

        # Should inherit port from base
        assert config.serve.port == 9000
        # And have its own test settings
        assert config.test.verbose is True

    def test_apply_nonexistent_profile(self) -> None:
        """Test applying a profile that doesn't exist (no-op)."""
        toml_str = """
[project]
name = "no-profile"

[serve]
port = 8000
"""
        config = JacConfig.from_toml_str(toml_str)

        # Should not raise, just do nothing
        config.apply_profile("nonexistent")
        assert config.serve.port == 8000


class TestJacConfigDependencyManagement:
    """Tests for adding/removing dependencies."""

    def test_add_python_dependency(self) -> None:
        """Test adding a Python dependency."""
        config = JacConfig()
        config.add_dependency("requests", ">=2.28.0")

        assert "requests" in config.dependencies
        assert config.dependencies["requests"] == ">=2.28.0"

    def test_add_dev_dependency(self) -> None:
        """Test adding a dev dependency."""
        config = JacConfig()
        config.add_dependency("pytest", ">=8.0.0", dev=True)

        assert "pytest" in config.dev_dependencies
        assert config.dev_dependencies["pytest"] == ">=8.0.0"

    def test_add_git_dependency(self) -> None:
        """Test adding a git dependency."""
        config = JacConfig()
        config.add_dependency(
            "my-plugin", "https://github.com/user/plugin.git", dep_type="git"
        )

        assert "my-plugin" in config.git_dependencies
        assert (
            config.git_dependencies["my-plugin"]["git"]
            == "https://github.com/user/plugin.git"
        )

    def test_add_npm_dependency(self) -> None:
        """Test adding an npm dependency."""
        config = JacConfig()
        config.add_dependency("react", "^19.0.0", dep_type="npm")

        assert "npm" in config.plugin_dependencies
        assert config.plugin_dependencies["npm"]["react"] == "^19.0.0"

    def test_remove_python_dependency(self) -> None:
        """Test removing a Python dependency."""
        config = JacConfig()
        config.dependencies["requests"] = ">=2.28.0"

        result = config.remove_dependency("requests")

        assert result is True
        assert "requests" not in config.dependencies

    def test_remove_nonexistent_dependency(self) -> None:
        """Test removing a dependency that doesn't exist."""
        config = JacConfig()

        result = config.remove_dependency("nonexistent")

        assert result is False


class TestJacConfigMethods:
    """Tests for other JacConfig methods."""

    def test_get_build_dir_default(self) -> None:
        """Test default build dir is .jac."""
        config = JacConfig()
        config.project_root = Path("/home/user/myproject")

        build_dir = config.get_build_dir()

        assert build_dir == Path("/home/user/myproject/.jac")

    def test_get_build_dir_custom(self) -> None:
        """Test custom build dir from jac.toml."""
        toml_str = """
[project]
name = "test"
version = "0.1.0"

[build]
dir = ".build"
"""
        config = JacConfig.from_toml_str(toml_str)
        config.project_root = Path("/home/user/myproject")

        build_dir = config.get_build_dir()

        assert build_dir == Path("/home/user/myproject/.build")

    def test_get_cache_dir(self) -> None:
        """Test cache dir is build_dir/cache."""
        config = JacConfig()
        config.project_root = Path("/home/user/myproject")

        cache_dir = config.get_cache_dir()

        assert cache_dir == Path("/home/user/myproject/.jac/cache")

    def test_get_packages_dir(self) -> None:
        """Test packages dir is build_dir/packages."""
        config = JacConfig()
        config.project_root = Path("/home/user/myproject")

        packages_dir = config.get_packages_dir()

        assert packages_dir == Path("/home/user/myproject/.jac/packages")

    def test_get_packages_dir_no_root(self) -> None:
        """Test getting packages directory with no project root."""
        config = JacConfig()
        config.project_root = None

        packages_dir = config.get_packages_dir()

        assert packages_dir == Path.cwd() / ".jac" / "packages"

    def test_get_data_dir(self) -> None:
        """Test data dir is build_dir/data."""
        config = JacConfig()
        config.project_root = Path("/home/user/myproject")

        data_dir = config.get_data_dir()

        assert data_dir == Path("/home/user/myproject/.jac/data")

    def test_get_client_dir(self) -> None:
        """Test client dir is build_dir/client."""
        config = JacConfig()
        config.project_root = Path("/home/user/myproject")

        client_dir = config.get_client_dir()

        assert client_dir == Path("/home/user/myproject/.jac/client")

    def test_all_dirs_use_custom_build_dir(self) -> None:
        """Test all artifact dirs use custom build dir."""
        toml_str = """
[project]
name = "test"

[build]
dir = ".custom-build"
"""
        config = JacConfig.from_toml_str(toml_str)
        config.project_root = Path("/project")

        assert config.get_build_dir() == Path("/project/.custom-build")
        assert config.get_cache_dir() == Path("/project/.custom-build/cache")
        assert config.get_packages_dir() == Path("/project/.custom-build/packages")
        assert config.get_data_dir() == Path("/project/.custom-build/data")
        assert config.get_client_dir() == Path("/project/.custom-build/client")

    def test_is_valid(self, temp_project: Path) -> None:
        """Test checking if config is valid."""
        config = JacConfig.load(temp_project / "jac.toml")
        assert config.is_valid() is True

        empty_config = JacConfig()
        assert empty_config.is_valid() is False

    def test_get_plugin_config(self) -> None:
        """Test getting plugin configuration."""
        toml_str = """
[project]
name = "plugin-test"

[plugins.byllm]
model = "gpt-4"
temperature = 0.5
"""
        config = JacConfig.from_toml_str(toml_str)

        byllm_config = config.get_plugin_config("byllm")

        assert byllm_config["model"] == "gpt-4"
        assert byllm_config["temperature"] == 0.5

    def test_get_plugin_config_missing(self) -> None:
        """Test getting missing plugin config returns empty dict."""
        config = JacConfig()

        result = config.get_plugin_config("nonexistent")

        assert result == {}

    def test_create_default_toml(self) -> None:
        """Test creating default TOML content via template registry."""
        from jaclang.project.template_registry import (
            get_template_registry,
            initialize_template_registry,
        )

        initialize_template_registry()
        registry = get_template_registry()
        template = registry.get_default()

        # Verify default template has expected config structure
        assert template is not None
        assert "project" in template.config
        assert "dependencies" in template.config


class TestGlobalConfig:
    """Tests for global config singleton."""

    def test_get_config_discovers(self, temp_project: Path) -> None:
        """Test get_config discovers and caches config."""
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_project)

            config = get_config()

            assert config is not None
            assert config.project.name == "test-project"
        finally:
            os.chdir(original_cwd)

    def test_set_config(self) -> None:
        """Test setting global config."""
        custom_config = JacConfig()
        custom_config.project.name = "custom"

        set_config(custom_config)

        retrieved = get_config()
        assert retrieved is not None
        assert retrieved.project.name == "custom"

    def test_get_config_force_discover(self, temp_project: Path) -> None:
        """Test forcing re-discovery of config."""
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_project)

            # First call to populate cache
            get_config()

            # Modify and cache different config
            custom = JacConfig()
            custom.project.name = "modified"
            set_config(custom)

            # Force rediscover
            config2 = get_config(force_discover=True)

            assert config2 is not None
            assert config2.project.name == "test-project"
        finally:
            os.chdir(original_cwd)
