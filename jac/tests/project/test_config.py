"""Tests for jaclang.project.config module."""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from jaclang.project.config import (
    JacConfig,
    discover_config_files,
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
lint = "jac lint . --fix"

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
        assert config.scripts["lint"] == "jac lint . --fix"

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

    def test_get_venv_dir(self) -> None:
        """Test venv dir is build_dir/venv."""
        config = JacConfig()
        config.project_root = Path("/home/user/myproject")

        venv_dir = config.get_venv_dir()

        assert venv_dir == Path("/home/user/myproject/.jac/venv")

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
        assert config.get_venv_dir() == Path("/project/.custom-build/venv")
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


class TestConfigFilesTracking:
    """Tests for config_files list tracking."""

    def test_load_initializes_config_files(self, temp_project: Path) -> None:
        """Test that load() initializes config_files with the base file."""
        config = JacConfig.load(temp_project / "jac.toml")

        assert len(config.config_files) == 1
        assert config.config_files[0] == temp_project / "jac.toml"

    def test_discover_initializes_config_files(self, temp_project: Path) -> None:
        """Test that discover() initializes config_files via load()."""
        config = JacConfig.discover(temp_project)

        assert config is not None
        assert len(config.config_files) == 1

    def test_active_profile_default_empty(self, temp_project: Path) -> None:
        """Test that active_profile is empty by default."""
        config = JacConfig.load(temp_project / "jac.toml")

        assert config.active_profile == ""


class TestDiscoverConfigFiles:
    """Tests for discover_config_files function."""

    def test_only_base_exists(self, temp_project: Path) -> None:
        """Test discovery when only jac.toml exists."""
        files = discover_config_files(temp_project)

        assert len(files) == 1
        assert files[0] == temp_project / "jac.toml"

    def test_with_profile_file(self, temp_project: Path) -> None:
        """Test discovery includes profile-specific file."""
        prod_toml = temp_project / "jac.prod.toml"
        prod_toml.write_text("[serve]\nport = 80\n")

        files = discover_config_files(temp_project, profile="prod")

        assert len(files) == 2
        assert files[0] == temp_project / "jac.toml"
        assert files[1] == prod_toml

    def test_with_local_file(self, temp_project: Path) -> None:
        """Test discovery includes jac.local.toml."""
        local_toml = temp_project / "jac.local.toml"
        local_toml.write_text("[run]\ncache = false\n")

        files = discover_config_files(temp_project)

        assert len(files) == 2
        assert files[0] == temp_project / "jac.toml"
        assert files[1] == local_toml

    def test_all_files_present(self, temp_project: Path) -> None:
        """Test discovery with base, profile, and local files."""
        (temp_project / "jac.staging.toml").write_text("[serve]\nport = 9000\n")
        (temp_project / "jac.local.toml").write_text("[run]\ncache = false\n")

        files = discover_config_files(temp_project, profile="staging")

        assert len(files) == 3
        assert files[0].name == "jac.toml"
        assert files[1].name == "jac.staging.toml"
        assert files[2].name == "jac.local.toml"

    def test_profile_file_missing(self, temp_project: Path) -> None:
        """Test discovery when profile file doesn't exist."""
        files = discover_config_files(temp_project, profile="nonexistent")

        # Only base, no profile file
        assert len(files) == 1
        assert files[0].name == "jac.toml"

    def test_no_profile_skips_profile_file(self, temp_project: Path) -> None:
        """Test that None profile doesn't look for profile files."""
        (temp_project / "jac.prod.toml").write_text("[serve]\nport = 80\n")

        files = discover_config_files(temp_project, profile=None)

        # Only base, even though jac.prod.toml exists
        assert len(files) == 1

    def test_empty_directory(self, temp_dir: Path) -> None:
        """Test discovery in directory with no config files."""
        empty_dir = temp_dir / "empty"
        empty_dir.mkdir()

        files = discover_config_files(empty_dir)

        assert len(files) == 0


class TestMergeFromTomlFile:
    """Tests for JacConfig.merge_from_toml_file."""

    def test_merge_simple_sections(self, temp_project: Path) -> None:
        """Test merging simple config sections (run, serve, test, etc.)."""
        config = JacConfig.load(temp_project / "jac.toml")
        assert config.run.cache is True
        assert config.serve.port == 8000

        overlay = temp_project / "overlay.toml"
        overlay.write_text("[run]\ncache = false\n\n[serve]\nport = 9000\n")

        config.merge_from_toml_file(overlay)

        assert config.run.cache is False
        assert config.serve.port == 9000

    def test_merge_preserves_unset_values(self, temp_project: Path) -> None:
        """Test that merge doesn't reset values not in overlay file."""
        config = JacConfig.load(temp_project / "jac.toml")
        assert config.run.main is True

        overlay = temp_project / "overlay.toml"
        overlay.write_text("[run]\ncache = false\n")

        config.merge_from_toml_file(overlay)

        # cache overridden, main preserved
        assert config.run.cache is False
        assert config.run.main is True

    def test_merge_project_kebab_case(self, temp_project: Path) -> None:
        """Test merging project section with kebab-case keys."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text('[project]\nentry-point = "app.jac"\n')

        config.merge_from_toml_file(overlay)

        assert config.project.entry_point == "app.jac"

    def test_merge_check_with_nested_lint(self, temp_project: Path) -> None:
        """Test merging check section with nested lint config."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text(
            '[check]\nwarnonly = true\n\n[check.lint]\nselect = ["all"]\n'
        )

        config.merge_from_toml_file(overlay)

        assert config.check.warnonly is True
        assert config.check.lint.select == ["all"]

    def test_merge_plugins_config(self, temp_project: Path) -> None:
        """Test merging plugins section."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text(
            '[plugins]\ndiscovery = "manual"\n\n'
            '[plugins.byllm]\ndefault_model = "gpt-4"\n'
        )

        config.merge_from_toml_file(overlay)

        assert config.plugins_config.discovery == "manual"
        assert "byllm" in config.plugins
        assert config.plugins["byllm"]["default_model"] == "gpt-4"

    def test_merge_dependencies(self, temp_project: Path) -> None:
        """Test merging dependencies (additive, not replacing)."""
        config = JacConfig.load(temp_project / "jac.toml")
        assert "requests" in config.dependencies

        overlay = temp_project / "overlay.toml"
        overlay.write_text('[dependencies]\nnumpy = ">=1.24.0"\n')

        config.merge_from_toml_file(overlay)

        # Both original and new dependency present
        assert "requests" in config.dependencies
        assert "numpy" in config.dependencies
        assert config.dependencies["numpy"] == ">=1.24.0"

    def test_merge_dependencies_override(self, temp_project: Path) -> None:
        """Test that merge overrides existing dependency versions."""
        config = JacConfig.load(temp_project / "jac.toml")
        assert config.dependencies["requests"] == ">=2.28.0"

        overlay = temp_project / "overlay.toml"
        overlay.write_text('[dependencies]\nrequests = ">=3.0.0"\n')

        config.merge_from_toml_file(overlay)

        assert config.dependencies["requests"] == ">=3.0.0"

    def test_merge_dev_dependencies(self, temp_project: Path) -> None:
        """Test merging dev-dependencies section."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text('[dev-dependencies]\nruff = ">=0.1.0"\n')

        config.merge_from_toml_file(overlay)

        assert "ruff" in config.dev_dependencies
        assert "pytest" in config.dev_dependencies  # original preserved

    def test_merge_scripts(self, temp_project: Path) -> None:
        """Test merging scripts section (additive)."""
        config = JacConfig.load(temp_project / "jac.toml")
        assert "test" in config.scripts

        overlay = temp_project / "overlay.toml"
        overlay.write_text('[scripts]\nbuild = "jac build"\n')

        config.merge_from_toml_file(overlay)

        assert config.scripts["test"] == "jac test"
        assert config.scripts["build"] == "jac build"

    def test_merge_environments(self, temp_project: Path) -> None:
        """Test merging environments section."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text(
            "[environments.ci]\n\n[environments.ci.test]\nverbose = true\n"
        )

        config.merge_from_toml_file(overlay)

        assert "ci" in config.environments

    def test_merge_tracks_config_file(self, temp_project: Path) -> None:
        """Test that merged files are tracked in config_files list."""
        config = JacConfig.load(temp_project / "jac.toml")
        assert len(config.config_files) == 1

        overlay = temp_project / "overlay.toml"
        overlay.write_text("[run]\ncache = false\n")

        config.merge_from_toml_file(overlay)

        assert len(config.config_files) == 2
        assert overlay in config.config_files

    def test_merge_no_duplicate_tracking(self, temp_project: Path) -> None:
        """Test that merging same file twice doesn't duplicate in config_files."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text("[run]\ncache = false\n")

        config.merge_from_toml_file(overlay)
        config.merge_from_toml_file(overlay)

        assert config.config_files.count(overlay) == 1

    def test_merge_updates_raw_data(self, temp_project: Path) -> None:
        """Test that _raw_data is updated for _is_explicitly_set checks."""
        config = JacConfig.load(temp_project / "jac.toml")
        assert "serve" not in config._raw_data  # not in base config

        overlay = temp_project / "overlay.toml"
        overlay.write_text("[serve]\nport = 9000\n")

        config.merge_from_toml_file(overlay)

        assert "serve" in config._raw_data
        assert config._raw_data["serve"]["port"] == 9000

    def test_merge_nonexistent_file(self, temp_project: Path) -> None:
        """Test that merging a nonexistent file is a no-op."""
        config = JacConfig.load(temp_project / "jac.toml")
        original_port = config.serve.port
        original_files = len(config.config_files)

        config.merge_from_toml_file(temp_project / "nonexistent.toml")

        assert config.serve.port == original_port
        assert len(config.config_files) == original_files

    def test_merge_ignores_unknown_keys(self, temp_project: Path) -> None:
        """Test that unknown keys in overlay sections are ignored."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text('[run]\nunknown_key = "value"\ncache = false\n')

        config.merge_from_toml_file(overlay)

        # Known key applied, unknown key silently ignored
        assert config.run.cache is False
        assert not hasattr(config.run, "unknown_key")

    def test_merge_malformed_toml(self, temp_project: Path) -> None:
        """Test that malformed TOML raises TOMLDecodeError."""
        import tomllib

        config = JacConfig.load(temp_project / "jac.toml")

        bad_file = temp_project / "bad.toml"
        bad_file.write_text("this is not valid toml [[[")

        with pytest.raises(tomllib.TOMLDecodeError):
            config.merge_from_toml_file(bad_file)

    def test_merge_env_interpolation(self, temp_project: Path) -> None:
        """Test that environment variables are interpolated in merged files."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text(
            '[plugins.byllm]\napi_key = "${TEST_API_KEY:-default_key}"\n'
        )

        os.environ.pop("TEST_API_KEY", None)
        config.merge_from_toml_file(overlay)

        assert config.plugins["byllm"]["api_key"] == "default_key"


class TestApplyProfileOverlay:
    """Tests for JacConfig.apply_profile_overlay."""

    def test_no_profile_applies_local_only(self, temp_project: Path) -> None:
        """Test that None profile only applies jac.local.toml."""
        config = JacConfig.load(temp_project / "jac.toml")

        local = temp_project / "jac.local.toml"
        local.write_text("[run]\ncache = false\n")

        config.apply_profile_overlay(None)

        assert config.run.cache is False
        assert config.active_profile == ""

    def test_empty_string_profile_treated_as_none(self, temp_project: Path) -> None:
        """Test that empty string profile behaves like None."""
        config = JacConfig.load(temp_project / "jac.toml")

        # Empty string is falsy, should skip profile steps
        config.apply_profile_overlay("")

        assert config.active_profile == ""

    def test_profile_merges_file_and_infile(self, temp_project: Path) -> None:
        """Test full overlay: profile file + in-file profile + local."""
        # Base config with environments
        jac_toml = temp_project / "jac.toml"
        jac_toml.write_text("""[project]
name = "test-project"

[serve]
port = 8000

[environments.prod]
[environments.prod.serve]
port = 443
""")

        # Profile file overrides build settings
        prod_toml = temp_project / "jac.prod.toml"
        prod_toml.write_text("[build]\ntypecheck = true\n")

        config = JacConfig.load(jac_toml)
        config.apply_profile_overlay("prod")

        # From jac.prod.toml (step 1)
        assert config.build.typecheck is True
        # From [environments.prod] in jac.toml (step 2)
        assert config.serve.port == 443
        # active_profile is set
        assert config.active_profile == "prod"

    def test_local_overrides_profile(self, temp_project: Path) -> None:
        """Test that jac.local.toml has highest priority."""
        jac_toml = temp_project / "jac.toml"
        jac_toml.write_text('[project]\nname = "test"\n\n[serve]\nport = 8000\n')

        prod_toml = temp_project / "jac.prod.toml"
        prod_toml.write_text("[serve]\nport = 80\n")

        local_toml = temp_project / "jac.local.toml"
        local_toml.write_text("[serve]\nport = 9999\n")

        config = JacConfig.load(jac_toml)
        config.apply_profile_overlay("prod")

        # local overrides both base and profile
        assert config.serve.port == 9999

    def test_profile_file_missing_infile_still_applied(
        self, temp_project: Path
    ) -> None:
        """Test that in-file profile applies even when profile file doesn't exist."""
        jac_toml = temp_project / "jac.toml"
        jac_toml.write_text("""[project]
name = "test"

[serve]
port = 8000

[environments.staging]
[environments.staging.serve]
port = 9000
""")

        config = JacConfig.load(jac_toml)
        # No jac.staging.toml exists
        config.apply_profile_overlay("staging")

        # In-file profile still applied
        assert config.serve.port == 9000
        assert config.active_profile == "staging"

    def test_nonexistent_profile_no_crash(self, temp_project: Path) -> None:
        """Test overlay with a profile that has no file and no in-file section."""
        config = JacConfig.load(temp_project / "jac.toml")
        original_port = config.serve.port

        # Should not raise, apply_profile handles missing profiles
        config.apply_profile_overlay("nonexistent")

        assert config.serve.port == original_port
        assert config.active_profile == "nonexistent"

    def test_no_project_root_early_return(self) -> None:
        """Test that overlay is a no-op when project_root is None."""
        config = JacConfig()
        assert config.project_root is None

        # Should not raise
        config.apply_profile_overlay("prod")

        assert config.active_profile == ""

    def test_overlay_tracks_all_config_files(self, temp_project: Path) -> None:
        """Test that config_files includes all loaded files after overlay."""
        jac_toml = temp_project / "jac.toml"
        jac_toml.write_text('[project]\nname = "test"\n')

        prod_toml = temp_project / "jac.prod.toml"
        prod_toml.write_text("[serve]\nport = 80\n")

        local_toml = temp_project / "jac.local.toml"
        local_toml.write_text("[run]\ncache = false\n")

        config = JacConfig.load(jac_toml)
        config.apply_profile_overlay("prod")

        assert len(config.config_files) == 3
        assert config.config_files[0] == jac_toml
        assert config.config_files[1] == prod_toml
        assert config.config_files[2] == local_toml

    def test_overlay_priority_order(self, temp_project: Path) -> None:
        """Test that overlay applies files in correct priority order.

        Priority: base < profile file < in-file profile < local.
        """
        jac_toml = temp_project / "jac.toml"
        jac_toml.write_text("""[project]
name = "test"

[test]
verbose = false

[environments.prod]
[environments.prod.test]
verbose = true
""")

        # Profile file sets fail_fast
        prod_toml = temp_project / "jac.prod.toml"
        prod_toml.write_text("[test]\nfail_fast = true\n")

        # Local file overrides verbose back to false
        local_toml = temp_project / "jac.local.toml"
        local_toml.write_text("[test]\nverbose = false\n")

        config = JacConfig.load(jac_toml)
        config.apply_profile_overlay("prod")

        # fail_fast from profile file (step 1)
        assert config.test.fail_fast is True
        # verbose was true from in-file profile (step 2), but local (step 3) overrides
        assert config.test.verbose is False

    def test_no_local_file_no_error(self, temp_project: Path) -> None:
        """Test overlay works when jac.local.toml doesn't exist."""
        config = JacConfig.load(temp_project / "jac.toml")

        # No jac.local.toml exists
        config.apply_profile_overlay("prod")

        # Should succeed, active_profile set
        assert config.active_profile == "prod"


class TestMultiProfileBugFixes:
    """Tests for multi-profile config bug fixes."""

    # --- Bug fix: storage.type -> storage_type mapping in merge ---

    def test_merge_storage_type_mapping(self, temp_project: Path) -> None:
        """Test that [storage] type key maps to storage_type field."""
        config = JacConfig.load(temp_project / "jac.toml")
        assert config.storage.storage_type == "local"  # default

        overlay = temp_project / "overlay.toml"
        overlay.write_text('[storage]\ntype = "s3"\nbase_path = "/data"\n')

        config.merge_from_toml_file(overlay)

        assert config.storage.storage_type == "s3"
        assert config.storage.base_path == "/data"

    # --- Bug fix: deep plugin merge in merge_from_toml_file ---

    def test_merge_plugins_deep_nested(self, temp_project: Path) -> None:
        """Test that nested plugin config dicts are deep-merged, not overwritten."""
        jac_toml = temp_project / "jac.toml"
        jac_toml.write_text(
            '[project]\nname = "test"\n\n'
            "[plugins.byllm]\n"
            'default_model = "gpt-4"\n\n'
            "[plugins.byllm.options]\n"
            "temperature = 0.7\n"
            "max_tokens = 1000\n"
        )

        config = JacConfig.load(jac_toml)
        assert config.plugins["byllm"]["options"]["temperature"] == 0.7
        assert config.plugins["byllm"]["options"]["max_tokens"] == 1000

        overlay = temp_project / "overlay.toml"
        overlay.write_text("[plugins.byllm.options]\ntemperature = 0.9\n")

        config.merge_from_toml_file(overlay)

        # temperature overridden, max_tokens preserved (deep merge)
        assert config.plugins["byllm"]["options"]["temperature"] == 0.9
        assert config.plugins["byllm"]["options"]["max_tokens"] == 1000
        # default_model preserved
        assert config.plugins["byllm"]["default_model"] == "gpt-4"

    # --- Bug fix: apply_profile now handles all sections ---

    def test_apply_profile_build_section(self) -> None:
        """Test that apply_profile handles build section."""
        config = JacConfig.from_toml_str(
            '[project]\nname = "test"\n\n'
            "[build]\ntypecheck = false\n\n"
            "[environments.prod]\n"
            "[environments.prod.build]\ntypecheck = true\n"
        )

        assert config.build.typecheck is False
        config.apply_profile("prod")
        assert config.build.typecheck is True

    def test_apply_profile_format_section(self) -> None:
        """Test that apply_profile handles format section."""
        config = JacConfig.from_toml_str(
            '[project]\nname = "test"\n\n'
            "[environments.dev]\n"
            "[environments.dev.format]\n"
            'outfile = "formatted.jac"\n'
        )

        config.apply_profile("dev")
        assert config.format.outfile == "formatted.jac"

    def test_apply_profile_dot_section(self) -> None:
        """Test that apply_profile handles dot section."""
        config = JacConfig.from_toml_str(
            '[project]\nname = "test"\n\n'
            "[environments.debug]\n"
            "[environments.debug.dot]\n"
            "depth = 5\ntraverse = true\n"
        )

        config.apply_profile("debug")
        assert config.dot.depth == 5
        assert config.dot.traverse is True

    def test_apply_profile_cache_section(self) -> None:
        """Test that apply_profile handles cache section."""
        config = JacConfig.from_toml_str(
            '[project]\nname = "test"\n\n'
            "[environments.ci]\n"
            "[environments.ci.cache]\n"
            "enabled = false\n"
        )

        config.apply_profile("ci")
        assert config.cache.enabled is False

    def test_apply_profile_storage_type_mapping(self) -> None:
        """Test that apply_profile handles storage with type -> storage_type mapping."""
        config = JacConfig.from_toml_str(
            '[project]\nname = "test"\n\n'
            "[environments.prod]\n"
            "[environments.prod.storage]\n"
            'type = "s3"\nbase_path = "/prod-data"\n'
        )

        config.apply_profile("prod")
        assert config.storage.storage_type == "s3"
        assert config.storage.base_path == "/prod-data"

    def test_apply_profile_check_with_lint(self) -> None:
        """Test that apply_profile handles check section with nested lint."""
        config = JacConfig.from_toml_str(
            '[project]\nname = "test"\n\n'
            "[environments.strict]\n"
            "[environments.strict.check]\n"
            "warnonly = false\n\n"
            "[environments.strict.check.lint]\n"
            'select = ["all"]\n'
        )

        config.apply_profile("strict")
        assert config.check.warnonly is False
        assert config.check.lint.select == ["all"]

    def test_apply_profile_project_kebab_case(self) -> None:
        """Test that apply_profile handles project section with kebab-case."""
        config = JacConfig.from_toml_str(
            '[project]\nname = "test"\nentry-point = "main.jac"\n\n'
            "[environments.alt]\n"
            "[environments.alt.project]\n"
            'entry-point = "app.jac"\n'
        )

        config.apply_profile("alt")
        assert config.project.entry_point == "app.jac"

    def test_apply_profile_dependencies_and_scripts(self) -> None:
        """Test that apply_profile handles dependencies and scripts."""
        config = JacConfig.from_toml_str(
            '[project]\nname = "test"\n\n'
            "[dependencies]\n"
            'requests = ">=2.0"\n\n'
            "[scripts]\n"
            'test = "jac test"\n\n'
            "[environments.prod]\n"
            "[environments.prod.dependencies]\n"
            'gunicorn = ">=21.0"\n\n'
            "[environments.prod.scripts]\n"
            'start = "jac start --port 80"\n'
        )

        config.apply_profile("prod")
        assert config.dependencies.get("gunicorn") == ">=21.0"
        assert config.dependencies.get("requests") == ">=2.0"  # preserved
        assert config.scripts.get("start") == "jac start --port 80"
        assert config.scripts.get("test") == "jac test"  # preserved

    def test_circular_profile_inheritance(self) -> None:
        """Test that circular profile inheritance does not cause infinite recursion."""
        config = JacConfig.from_toml_str(
            '[project]\nname = "test"\n\n'
            "[environments.a]\n"
            'inherits = "b"\n'
            "[environments.a.serve]\nport = 1000\n\n"
            "[environments.b]\n"
            'inherits = "a"\n'
            "[environments.b.serve]\nport = 2000\n"
        )

        # Should not raise RecursionError
        config.apply_profile("a")

        # "a" inherits "b" first (port=2000), then "a" overrides (port=1000)
        assert config.serve.port == 1000

    def test_three_way_circular_inheritance(self) -> None:
        """Test that three-way circular inheritance is handled."""
        config = JacConfig.from_toml_str(
            '[project]\nname = "test"\n\n'
            "[environments.a]\n"
            'inherits = "b"\n'
            "[environments.a.serve]\nport = 1000\n\n"
            "[environments.b]\n"
            'inherits = "c"\n'
            "[environments.b.serve]\nport = 2000\n\n"
            "[environments.c]\n"
            'inherits = "a"\n'
            "[environments.c.serve]\nport = 3000\n"
        )

        # Should not raise RecursionError
        config.apply_profile("a")
        assert config.serve.port == 1000

    # --- Bug fix: discover() with profile parameter ---

    def test_discover_with_profile(self, temp_project: Path) -> None:
        """Test that discover() applies profile when provided."""
        jac_toml = temp_project / "jac.toml"
        jac_toml.write_text(
            '[project]\nname = "test-project"\nversion = "0.1.0"\n\n'
            "[serve]\nport = 8000\n\n"
            "[environments.prod]\n"
            "[environments.prod.serve]\nport = 443\n"
        )

        config = JacConfig.discover(temp_project, profile="prod")

        assert config is not None
        assert config.serve.port == 443
        assert config.active_profile == "prod"

    def test_discover_with_profile_none(self, temp_project: Path) -> None:
        """Test that discover() without profile does not apply overlay."""
        config = JacConfig.discover(temp_project, profile=None)

        assert config is not None
        assert config.active_profile == ""

    # --- Bug fix: mutable default config_files ---

    def test_config_files_none_default(self) -> None:
        """Test that JacConfig() has None config_files by default."""
        config = JacConfig()
        assert config.config_files is None

    def test_config_files_initialized_on_load(self, temp_project: Path) -> None:
        """Test that load() initializes config_files to a list."""
        config = JacConfig.load(temp_project / "jac.toml")
        assert config.config_files is not None
        assert len(config.config_files) == 1

    def test_merge_initializes_none_config_files(self) -> None:
        """Test that merge_from_toml_file handles None config_files."""
        import tempfile

        config = JacConfig()
        assert config.config_files is None

        with tempfile.NamedTemporaryFile(suffix=".toml", mode="w", delete=False) as f:
            f.write("[run]\ncache = false\n")
            f.flush()
            toml_path = Path(f.name)

        try:
            config.merge_from_toml_file(toml_path)
            assert config.config_files is not None
            assert toml_path in config.config_files
        finally:
            toml_path.unlink()

    # --- Merge tests for previously untested sections ---

    def test_merge_format_section(self, temp_project: Path) -> None:
        """Test merging format section."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text('[format]\noutfile = "out.jac"\n')

        config.merge_from_toml_file(overlay)

        assert config.format.outfile == "out.jac"

    def test_merge_dot_section(self, temp_project: Path) -> None:
        """Test merging dot section."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text("[dot]\ndepth = 3\ntraverse = true\n")

        config.merge_from_toml_file(overlay)

        assert config.dot.depth == 3
        assert config.dot.traverse is True

    def test_merge_cache_section(self, temp_project: Path) -> None:
        """Test merging cache section."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text('[cache]\nenabled = false\ndir = ".custom_cache"\n')

        config.merge_from_toml_file(overlay)

        assert config.cache.enabled is False
        assert config.cache.dir == ".custom_cache"

    def test_merge_environment_section(self, temp_project: Path) -> None:
        """Test merging environment section (default_profile)."""
        config = JacConfig.load(temp_project / "jac.toml")

        overlay = temp_project / "overlay.toml"
        overlay.write_text('[environment]\ndefault_profile = "dev"\n')

        config.merge_from_toml_file(overlay)

        assert config.environment.default_profile == "dev"


# ===============================================================================
# Integration tests for multi-file config layering
# ===============================================================================


BASE_TOML = """\
[project]
name = "jactastic"

[serve]
port = 8090
base_route_app = "app"

[plugins.client]

[dependencies.npm]
jac-client-node = "1.0.4"

[dev-dependencies]
watchdog = ">=3.0"
"""

PROD_TOML = """\
[serve]
port = 80

[plugins.client]
minify = true

[plugins.byllm]
default_model = "gpt-4"
"""

LOCAL_TOML = """\
[serve]
port = 9000

[run]
cache = false
"""


def _write_multi_profile(project_dir: Path) -> None:
    """Write base, prod, and local TOML files into project_dir."""
    (project_dir / "jac.toml").write_text(BASE_TOML)
    (project_dir / "jac.prod.toml").write_text(PROD_TOML)
    (project_dir / "jac.local.toml").write_text(LOCAL_TOML)


class TestJactasticMultiProfile:
    """Integration tests for multi-file config layering.

    Each test writes three TOML files into temp_project:
      - jac.toml        (base: serve.port=8090, plugins.client, npm deps)
      - jac.prod.toml   (serve.port=80, plugins.client.minify=true, plugins.byllm)
      - jac.local.toml  (serve.port=9000, run.cache=false)
    """

    def test_load_base_only(self, temp_project: Path) -> None:
        """Loading jac.toml alone gives base values, no profile."""
        _write_multi_profile(temp_project)
        config = JacConfig.load(temp_project / "jac.toml")

        assert config.project.name == "jactastic"
        assert config.serve.base_route_app == "app"
        assert config.serve.port == 8090
        assert config.active_profile == ""
        assert len(config.config_files) == 1

    def test_discover_no_profile(self, temp_project: Path) -> None:
        """discover() without profile loads base only."""
        _write_multi_profile(temp_project)
        config = JacConfig.discover(temp_project, profile=None)

        assert config is not None
        assert config.project.name == "jactastic"
        assert config.active_profile == ""

    def test_discover_with_prod_profile(self, temp_project: Path) -> None:
        """discover(profile='prod') applies base -> prod file -> local."""
        _write_multi_profile(temp_project)
        config = JacConfig.discover(temp_project, profile="prod")

        assert config is not None
        assert config.active_profile == "prod"

        # From jac.prod.toml
        assert "byllm" in config.plugins
        assert config.plugins["byllm"]["default_model"] == "gpt-4"
        assert config.plugins["client"]["minify"] is True

        # From jac.local.toml (highest priority)
        assert config.serve.port == 9000
        assert config.run.cache is False

    def test_prod_without_local_override(self, temp_project: Path) -> None:
        """Verify what prod profile sets before local overrides it."""
        _write_multi_profile(temp_project)
        config = JacConfig.load(temp_project / "jac.toml")
        config.merge_from_toml_file(temp_project / "jac.prod.toml")

        assert config.serve.port == 80
        assert config.serve.base_route_app == "app"
        assert config.plugins["client"]["minify"] is True

    def test_local_overrides_prod_port(self, temp_project: Path) -> None:
        """jac.local.toml port=9000 beats jac.prod.toml port=80."""
        _write_multi_profile(temp_project)
        config = JacConfig.load(temp_project / "jac.toml")
        config.apply_profile_overlay("prod")

        assert config.serve.port == 9000

    def test_config_files_tracked_in_order(self, temp_project: Path) -> None:
        """All three files tracked: base, prod, local."""
        _write_multi_profile(temp_project)
        config = JacConfig.discover(temp_project, profile="prod")

        assert config is not None
        assert len(config.config_files) == 3
        assert config.config_files[0].name == "jac.toml"
        assert config.config_files[1].name == "jac.prod.toml"
        assert config.config_files[2].name == "jac.local.toml"

    def test_base_dependencies_preserved(self, temp_project: Path) -> None:
        """Profile overlay doesn't wipe base npm dependencies."""
        _write_multi_profile(temp_project)
        config = JacConfig.discover(temp_project, profile="prod")

        assert config is not None
        assert "npm" in config.plugin_dependencies
        assert config.plugin_dependencies["npm"]["jac-client-node"] == "1.0.4"
        assert "watchdog" in config.dev_dependencies

    def test_discover_config_files_for_prod(self, temp_project: Path) -> None:
        """discover_config_files returns correct files for prod profile."""
        _write_multi_profile(temp_project)
        files = discover_config_files(temp_project, profile="prod")

        assert len(files) == 3
        assert files[0] == temp_project / "jac.toml"
        assert files[1] == temp_project / "jac.prod.toml"
        assert files[2] == temp_project / "jac.local.toml"

    def test_discover_config_files_no_profile(self, temp_project: Path) -> None:
        """Without profile, only base and local are found."""
        _write_multi_profile(temp_project)
        files = discover_config_files(temp_project)

        assert len(files) == 2
        assert files[0] == temp_project / "jac.toml"
        assert files[1] == temp_project / "jac.local.toml"

    def test_nonexistent_profile_still_gets_local(self, temp_project: Path) -> None:
        """A profile with no matching file still picks up jac.local.toml."""
        _write_multi_profile(temp_project)
        config = JacConfig.discover(temp_project, profile="staging")

        assert config is not None
        assert config.active_profile == "staging"
        assert config.serve.port == 9000
        assert config.run.cache is False

    def test_plugin_deep_merge_across_files(self, temp_project: Path) -> None:
        """Plugins from base and prod are deep-merged, not replaced."""
        _write_multi_profile(temp_project)
        config = JacConfig.discover(temp_project, profile="prod")

        assert config is not None
        assert "client" in config.plugins
        assert config.plugins["client"]["minify"] is True
        assert "byllm" in config.plugins
        assert config.plugins["byllm"]["default_model"] == "gpt-4"
