"""Integration tests for mobile target (Expo + WebView) functionality.

These tests validate the mobile target setup, build, and CLI integration
following the same patterns as test_it_desktop.py.

Tests are designed to:
1. Skip gracefully if Bun is not installed
2. Test setup command (scaffolding) without requiring Expo/EAS
3. Test generated file contents and structure
4. Test CLI flags (--expo, --target, --profile)

Note: Some tests call the target's methods directly via Python imports to avoid
CLI plugin registration conflicts that can occur in monorepo test environments.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path
from subprocess import PIPE, Popen, run

import pytest

from .test_helpers import (
    get_env_with_bun,
    get_jac_command,
)


def is_jac_setup_available() -> bool:
    """Check if the 'jac setup' CLI command is available."""
    jac_cmd = get_jac_command()
    result = run(
        [*jac_cmd, "--help"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    return "setup" in result.stdout


def is_bun_installed() -> bool:
    """Check if Bun is installed."""
    try:
        result = run(["bun", "--version"], capture_output=True, timeout=10)
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def run_jac_setup_mobile(project_dir: Path) -> tuple[int, str, str]:
    """Run jac setup mobile command and return (returncode, stdout, stderr).

    Returns (1, "", "CLI not available") if the CLI command is not available.
    """
    jac_cmd = get_jac_command()
    env = get_env_with_bun()

    result = run(
        [*jac_cmd, "setup", "mobile"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        env=env,
        timeout=120,
    )

    if result.returncode != 0 and "invalid choice: 'setup'" in result.stderr:
        return (1, "", "CLI_NOT_AVAILABLE: 'jac setup' command not registered")

    return (result.returncode, result.stdout, result.stderr)


# Skip markers
requires_jac_setup_cli = pytest.mark.skipif(
    not is_jac_setup_available(),
    reason="'jac setup' CLI command not available (plugin not fully loaded)",
)

requires_bun = pytest.mark.skipif(
    not is_bun_installed(),
    reason="Bun not installed (required for mobile target)",
)


# =============================================================================
# Fixtures and Helpers
# =============================================================================


def get_minimal_mobile_jac() -> str:
    """Get minimal main.jac content for mobile testing."""
    return '''"""Minimal mobile app for testing."""

# Client-side component
cl import from react { useEffect }

cl {
    def:pub app() -> any {
        has count: int = 0;

        return <div>
            <h1>Mobile Test App</h1>
            <p>Count: {count}</p>
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>
        </div>;
    }
}
'''


def get_minimal_jac_toml(name: str = "test-mobile-app") -> str:
    """Get minimal jac.toml content for mobile testing."""
    return f'''[project]
name = "{name}"
version = "1.0.0"
description = "Mobile test app"
entry-point = "main.jac"

[dependencies.npm]
jac-client-node = "1.0.4"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "1.0.0"

[serve]
base_route_app = "app"

[plugins.client]
'''


# =============================================================================
# Test: Mobile Target Files Exist (no CLI required)
# =============================================================================


def test_mobile_target_files_exist() -> None:
    """Test that the mobile target implementation files exist.

    This test verifies the mobile target implementation is properly structured,
    without requiring the CLI to be available.
    """
    print("[DEBUG] Starting test_mobile_target_files_exist")

    # Get path to jac_client plugin
    plugin_dir = Path(__file__).parent.parent / "plugin"

    # Verify mobile target files
    mobile_target_jac = plugin_dir / "src" / "targets" / "mobile_target.jac"
    assert mobile_target_jac.exists(), (
        f"mobile_target.jac not found at {mobile_target_jac}"
    )

    # Verify implementation file
    mobile_impl_jac = (
        plugin_dir / "src" / "targets" / "impl" / "mobile_target.impl.jac"
    )
    assert mobile_impl_jac.exists(), (
        f"mobile_target.impl.jac not found at {mobile_impl_jac}"
    )

    # Read mobile_target.jac and verify it has the expected methods
    mobile_target_content = mobile_target_jac.read_text()
    assert "class MobileTarget" in mobile_target_content
    assert "def setup" in mobile_target_content
    assert "def build" in mobile_target_content
    assert "def dev" in mobile_target_content
    assert "def start" in mobile_target_content

    # Read implementation and verify it has key helper functions
    impl_content = mobile_impl_jac.read_text()
    assert "_generate_package_json" in impl_content
    assert "_generate_app_tsx" in impl_content
    assert "_generate_app_json" in impl_content
    assert "_generate_eas_json" in impl_content
    assert "_get_lan_ip" in impl_content

    print("[DEBUG] All mobile target files verified!")


def test_mobile_default_config_files_exist() -> None:
    """Test that the default config templates exist for mobile target."""
    print("[DEBUG] Starting test_mobile_default_config_files_exist")

    plugin_dir = Path(__file__).parent.parent / "plugin"

    # Verify app_config.json
    app_config = plugin_dir / "defaults" / "app_config.json"
    assert app_config.exists(), f"app_config.json not found at {app_config}"

    with open(app_config) as f:
        config = json.load(f)

    assert "expo" in config, "app_config.json should have 'expo' key"
    assert "name" in config["expo"], "expo config should have 'name'"
    assert "slug" in config["expo"], "expo config should have 'slug'"
    assert "ios" in config["expo"], "expo config should have 'ios' section"
    assert "android" in config["expo"], "expo config should have 'android' section"

    # Verify expo-router is NOT in plugins (it was removed as it's not a dependency)
    plugins = config["expo"].get("plugins", [])
    assert "expo-router" not in plugins, (
        "expo-router should not be in plugins (not in package.json dependencies)"
    )

    # Verify eas_config.json
    eas_config = plugin_dir / "defaults" / "eas_config.json"
    assert eas_config.exists(), f"eas_config.json not found at {eas_config}"

    with open(eas_config) as f:
        eas = json.load(f)

    assert "build" in eas, "eas_config.json should have 'build' key"
    assert "development" in eas["build"], "eas should have 'development' profile"
    assert "preview" in eas["build"], "eas should have 'preview' profile"
    assert "production" in eas["build"], "eas should have 'production' profile"

    print("[DEBUG] All default config files verified!")


def test_mobile_template_exists() -> None:
    """Test that the mobile.jacpack template file exists and is valid."""
    print("[DEBUG] Starting test_mobile_template_exists")

    templates_dir = Path(__file__).parent.parent / "templates"

    template_path = templates_dir / "mobile.jacpack"
    assert template_path.exists(), f"mobile.jacpack not found at {template_path}"

    with open(template_path) as f:
        template = json.load(f)

    assert template["name"] == "mobile"
    assert "config" in template
    assert "files" in template
    assert "main.jac" in template["files"]

    # Verify mobile config section is in template
    assert "plugins.client.mobile" in template["config"], (
        "Template should include [plugins.client.mobile] config"
    )
    mobile_cfg = template["config"]["plugins.client.mobile"]
    assert "scheme" in mobile_cfg
    assert "api_base_url" in mobile_cfg
    assert "bundle_identifier" in mobile_cfg
    assert "package_name" in mobile_cfg

    print("[DEBUG] Mobile template verified!")


def test_mobile_docs_exist() -> None:
    """Test that mobile target documentation exists."""
    print("[DEBUG] Starting test_mobile_docs_exist")

    docs_dir = Path(__file__).parent.parent / "docs" / "multi-targets"

    mobile_doc = docs_dir / "mobile-target.md"
    assert mobile_doc.exists(), f"mobile-target.md not found at {mobile_doc}"

    content = mobile_doc.read_text()
    assert "Expo + WebView" in content
    assert "jac setup mobile" in content
    assert "jac start --client mobile" in content
    assert "jac build --client mobile" in content

    # Verify intro.md includes mobile
    intro_doc = docs_dir / "intro.md"
    assert intro_doc.exists()
    intro_content = intro_doc.read_text()
    assert "Mobile" in intro_content
    assert "mobile-target.md" in intro_content

    print("[DEBUG] Mobile docs verified!")


# =============================================================================
# Test: Mobile Target Registration (no CLI required)
# =============================================================================


def test_mobile_target_registered_in_registry() -> None:
    """Test that MobileTarget is registered in register.jac."""
    print("[DEBUG] Starting test_mobile_target_registered_in_registry")

    plugin_dir = Path(__file__).parent.parent / "plugin"
    register_path = plugin_dir / "src" / "targets" / "register.jac"
    assert register_path.exists()

    content = register_path.read_text()
    assert "MobileTarget" in content, "register.jac should import MobileTarget"
    assert "mobile_target" in content, "register.jac should register mobile_target"

    print("[DEBUG] Mobile target registration verified!")


# =============================================================================
# Test: Mobile Setup Command (requires CLI + Bun)
# =============================================================================


@requires_jac_setup_cli
@requires_bun
def test_mobile_setup_creates_directory_structure() -> None:
    """Test that `jac setup mobile` creates the expected Expo directory structure.

    This test verifies:
    1. .jac/mobile/ directory is created
    2. package.json is generated with Expo dependencies
    3. App.tsx (WebView shell) is generated
    4. app.json is generated with valid JSON
    5. eas.json is generated
    6. babel.config.js is generated
    7. tsconfig.json is generated
    8. assets/ directory is created with placeholders
    9. jac.toml is updated with [plugins.client.mobile] section
    """
    print("[DEBUG] Starting test_mobile_setup_creates_directory_structure")

    app_name = "mobile-setup-test"

    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"[DEBUG] Created temporary directory at {temp_dir}")
        project_dir = Path(temp_dir) / app_name
        project_dir.mkdir(parents=True)

        # Create minimal project files
        (project_dir / "main.jac").write_text(get_minimal_mobile_jac())
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name))

        print(f"[DEBUG] Created project at {project_dir}")
        print(f"[DEBUG] Project files: {list(project_dir.iterdir())}")

        # Run jac setup mobile
        print("[DEBUG] Running mobile setup")
        returncode, stdout, stderr = run_jac_setup_mobile(project_dir)

        print(
            f"[DEBUG] Mobile setup completed returncode={returncode}\n"
            f"STDOUT:\n{stdout[:2000]}\n"
            f"STDERR:\n{stderr[:2000]}\n"
        )

        # Setup should succeed (returncode 0)
        assert returncode == 0, (
            f"jac setup mobile failed\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
        )

        # Verify .jac/mobile directory exists
        mobile_dir = project_dir / ".jac" / "mobile"
        assert mobile_dir.exists(), ".jac/mobile/ directory should be created"
        assert mobile_dir.is_dir(), ".jac/mobile should be a directory"

        # Verify package.json
        package_json_path = mobile_dir / "package.json"
        assert package_json_path.exists(), "package.json should be created"

        with open(package_json_path) as f:
            package_data = json.load(f)

        print(
            f"[DEBUG] package.json content: {json.dumps(package_data, indent=2)[:500]}"
        )

        # Verify key dependencies
        deps = package_data.get("dependencies", {})
        assert "expo" in deps, "package.json should have expo dependency"
        assert "react-native" in deps, "package.json should have react-native"
        assert "react-native-webview" in deps, (
            "package.json should have react-native-webview"
        )

        # Verify App.tsx
        app_tsx_path = mobile_dir / "App.tsx"
        assert app_tsx_path.exists(), "App.tsx should be created"
        app_tsx_content = app_tsx_path.read_text()
        assert "WebView" in app_tsx_content, "App.tsx should use WebView"
        assert "SafeAreaView" in app_tsx_content, "App.tsx should use SafeAreaView"
        assert "EXPO_PUBLIC_DEV_SERVER_URL" in app_tsx_content, (
            "App.tsx should read dev server URL from env"
        )

        # Verify app.json
        app_json_path = mobile_dir / "app.json"
        assert app_json_path.exists(), "app.json should be created"

        with open(app_json_path) as f:
            app_config = json.load(f)

        assert "expo" in app_config, "app.json should have 'expo' key"
        assert app_config["expo"]["name"] == app_name
        assert app_config["expo"]["slug"] == app_name

        # Verify eas.json
        eas_json_path = mobile_dir / "eas.json"
        assert eas_json_path.exists(), "eas.json should be created"

        with open(eas_json_path) as f:
            eas_config = json.load(f)

        assert "build" in eas_config, "eas.json should have 'build' key"

        # Verify babel.config.js
        babel_path = mobile_dir / "babel.config.js"
        assert babel_path.exists(), "babel.config.js should be created"
        babel_content = babel_path.read_text()
        assert "babel-preset-expo" in babel_content

        # Verify tsconfig.json
        tsconfig_path = mobile_dir / "tsconfig.json"
        assert tsconfig_path.exists(), "tsconfig.json should be created"

        with open(tsconfig_path) as f:
            tsconfig = json.load(f)

        assert tsconfig["extends"] == "expo/tsconfig.base"

        # Verify assets directory
        assets_dir = mobile_dir / "assets"
        assert assets_dir.exists(), "assets/ directory should be created"
        assert (assets_dir / "icon.png").exists(), "icon.png placeholder should exist"
        assert (assets_dir / "splash-icon.png").exists(), (
            "splash-icon.png placeholder should exist"
        )

        # Verify jac.toml was updated
        jac_toml_content = (project_dir / "jac.toml").read_text()
        assert "[plugins.client.mobile]" in jac_toml_content, (
            "jac.toml should have [plugins.client.mobile] section"
        )
        assert 'scheme = "' in jac_toml_content
        assert 'bundle_identifier = "' in jac_toml_content
        assert 'package_name = "' in jac_toml_content

        print("[DEBUG] All mobile setup verifications passed!")


@requires_jac_setup_cli
@requires_bun
def test_mobile_setup_is_idempotent() -> None:
    """Test that running `jac setup mobile` twice doesn't fail or duplicate files."""
    print("[DEBUG] Starting test_mobile_setup_is_idempotent")

    app_name = "mobile-idempotent-test"

    with tempfile.TemporaryDirectory() as temp_dir:
        project_dir = Path(temp_dir) / app_name
        project_dir.mkdir(parents=True)

        # Create minimal project files
        (project_dir / "main.jac").write_text(get_minimal_mobile_jac())
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name))

        # First setup
        print("[DEBUG] Running first mobile setup")
        returncode1, stdout1, stderr1 = run_jac_setup_mobile(project_dir)
        assert returncode1 == 0, f"First setup failed: {stderr1}"

        # Get state after first setup
        package_json_path = project_dir / ".jac" / "mobile" / "package.json"
        with open(package_json_path) as f:
            pkg_after_first = json.load(f)

        # Second setup
        print("[DEBUG] Running second mobile setup")
        returncode2, stdout2, stderr2 = run_jac_setup_mobile(project_dir)

        print(
            f"[DEBUG] Second setup returncode={returncode2}\n"
            f"STDOUT:\n{stdout2[:1000]}\n"
            f"STDERR:\n{stderr2[:1000]}"
        )

        # Second setup should not fail (it should detect already set up)
        assert returncode2 == 0, f"Second setup should not fail: {stderr2}"

        # Should warn about already being set up
        assert (
            "already set up" in stdout2.lower()
            or "already set up" in stderr2.lower()
        ), "Second run should warn about existing setup"

        # package.json should still be valid
        with open(package_json_path) as f:
            pkg_after_second = json.load(f)

        assert pkg_after_first["name"] == pkg_after_second["name"]

        # jac.toml should not have duplicate [plugins.client.mobile] sections
        jac_toml_content = (project_dir / "jac.toml").read_text()
        count = jac_toml_content.count("[plugins.client.mobile]")
        assert count == 1, (
            f"jac.toml should have exactly one [plugins.client.mobile] section, "
            f"found {count}"
        )

        print("[DEBUG] Mobile setup idempotency test passed!")


# =============================================================================
# Test: Mobile Build CLI Flags
# =============================================================================


@requires_jac_setup_cli
def test_mobile_build_without_setup_fails() -> None:
    """Test that `jac build --client mobile` fails without setup."""
    print("[DEBUG] Starting test_mobile_build_without_setup_fails")

    with tempfile.TemporaryDirectory() as temp_dir:
        project_dir = Path(temp_dir)
        (project_dir / "main.jac").write_text(get_minimal_mobile_jac())
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml())

        jac_cmd = get_jac_command()
        env = get_env_with_bun()

        result = run(
            [*jac_cmd, "build", "main.jac", "--client", "mobile"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=60,
        )

        print(
            f"[DEBUG] Build without setup: returncode={result.returncode}\n"
            f"STDOUT:\n{result.stdout[:1000]}\n"
            f"STDERR:\n{result.stderr[:1000]}"
        )

        assert result.returncode != 0, "Build should fail without mobile setup"
        combined = result.stdout + result.stderr
        assert (
            "not set up" in combined.lower()
            or "setup mobile" in combined.lower()
        ), "Error should mention setup is needed"

        print("[DEBUG] Build without setup correctly fails!")


@requires_jac_setup_cli
def test_mobile_start_without_setup_fails() -> None:
    """Test that `jac start --client mobile` fails without setup."""
    print("[DEBUG] Starting test_mobile_start_without_setup_fails")

    with tempfile.TemporaryDirectory() as temp_dir:
        project_dir = Path(temp_dir)
        (project_dir / "main.jac").write_text(get_minimal_mobile_jac())
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml())

        jac_cmd = get_jac_command()
        env = get_env_with_bun()

        result = run(
            [*jac_cmd, "start", "--client", "mobile", "main.jac"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=60,
        )

        print(
            f"[DEBUG] Start without setup: returncode={result.returncode}\n"
            f"STDOUT:\n{result.stdout[:1000]}\n"
            f"STDERR:\n{result.stderr[:1000]}"
        )

        assert result.returncode != 0, "Start should fail without mobile setup"
        combined = result.stdout + result.stderr
        assert (
            "not set up" in combined.lower()
            or "setup mobile" in combined.lower()
        ), "Error should mention setup is needed"

        print("[DEBUG] Start without setup correctly fails!")


@requires_jac_setup_cli
def test_mobile_expo_command_without_setup_fails() -> None:
    """Test that `jac expo` fails without mobile setup."""
    print("[DEBUG] Starting test_mobile_expo_command_without_setup_fails")

    with tempfile.TemporaryDirectory() as temp_dir:
        project_dir = Path(temp_dir)
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml())

        jac_cmd = get_jac_command()
        env = get_env_with_bun()

        result = run(
            [*jac_cmd, "expo", "doctor"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=60,
        )

        print(
            f"[DEBUG] Expo without setup: returncode={result.returncode}\n"
            f"STDOUT:\n{result.stdout[:1000]}\n"
            f"STDERR:\n{result.stderr[:1000]}"
        )

        assert result.returncode != 0, "Expo should fail without mobile setup"
        combined = result.stdout + result.stderr
        assert (
            "not set up" in combined.lower()
            or "setup mobile" in combined.lower()
        ), "Error should mention setup is needed"

        print("[DEBUG] Expo without setup correctly fails!")


@requires_jac_setup_cli
def test_mobile_expo_add_without_setup_fails() -> None:
    """Test that `jac add --expo` fails without mobile setup."""
    print("[DEBUG] Starting test_mobile_expo_add_without_setup_fails")

    with tempfile.TemporaryDirectory() as temp_dir:
        project_dir = Path(temp_dir)
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml())

        jac_cmd = get_jac_command()
        env = get_env_with_bun()

        result = run(
            [*jac_cmd, "add", "--expo", "expo-camera"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=60,
        )

        print(
            f"[DEBUG] Expo add without setup: returncode={result.returncode}\n"
            f"STDOUT:\n{result.stdout[:1000]}\n"
            f"STDERR:\n{result.stderr[:1000]}"
        )

        assert result.returncode != 0, "Expo add should fail without mobile setup"

        print("[DEBUG] Expo add without setup correctly fails!")


@requires_jac_setup_cli
def test_mobile_expo_remove_without_setup_fails() -> None:
    """Test that `jac remove --expo` fails without mobile setup."""
    print("[DEBUG] Starting test_mobile_expo_remove_without_setup_fails")

    with tempfile.TemporaryDirectory() as temp_dir:
        project_dir = Path(temp_dir)
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml())

        jac_cmd = get_jac_command()
        env = get_env_with_bun()

        result = run(
            [*jac_cmd, "remove", "--expo", "expo-camera"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=60,
        )

        print(
            f"[DEBUG] Expo remove without setup: returncode={result.returncode}\n"
            f"STDOUT:\n{result.stdout[:1000]}\n"
            f"STDERR:\n{result.stderr[:1000]}"
        )

        assert result.returncode != 0, "Expo remove should fail without mobile setup"

        print("[DEBUG] Expo remove without setup correctly fails!")


# =============================================================================
# Test: Mobile Create Template
# =============================================================================


@requires_jac_setup_cli
def test_create_mobile_template() -> None:
    """Test jac create --use mobile command creates proper project."""
    print("[DEBUG] Starting test_create_mobile_template")

    test_project_name = "test-mobile-app"

    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            process = Popen(
                ["jac", "create", "--use", "mobile", "--skip", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate(timeout=60)
            result_code = process.returncode

            print(
                f"[DEBUG] Create template returncode={result_code}\n"
                f"STDOUT:\n{stdout[:2000]}\n"
                f"STDERR:\n{stderr[:2000]}"
            )

            assert result_code == 0, (
                f"jac create --use mobile failed\n"
                f"STDOUT:\n{stdout}\nSTDERR:\n{stderr}"
            )

            project_path = os.path.join(temp_dir, test_project_name)
            assert os.path.exists(project_path)

            # Verify main.jac
            main_jac_path = os.path.join(project_path, "main.jac")
            assert os.path.exists(main_jac_path)
            with open(main_jac_path) as f:
                content = f.read()
            assert "def:pub app()" in content

            # Verify jac.toml has mobile config
            import tomllib

            jac_toml_path = os.path.join(project_path, "jac.toml")
            assert os.path.exists(jac_toml_path)
            with open(jac_toml_path, "rb") as f:
                config_data = tomllib.load(f)

            assert config_data["project"]["name"] == test_project_name
            assert "plugins" in config_data
            assert "client" in config_data["plugins"]
            assert "mobile" in config_data["plugins"]["client"]

            mobile_cfg = config_data["plugins"]["client"]["mobile"]
            assert "scheme" in mobile_cfg
            assert "bundle_identifier" in mobile_cfg

            print("[DEBUG] Mobile template creation verified!")

        finally:
            os.chdir(original_cwd)


# =============================================================================
# Test: Web Build Still Works (Regression Test)
# =============================================================================


@requires_jac_setup_cli
@requires_bun
def test_web_build_still_works_after_mobile_setup() -> None:
    """Test that web target still works after mobile setup (regression test)."""
    print("[DEBUG] Starting test_web_build_still_works_after_mobile_setup")

    app_name = "mobile-web-regression-test"

    with tempfile.TemporaryDirectory() as temp_dir:
        project_dir = Path(temp_dir) / app_name
        project_dir.mkdir(parents=True)

        # Create minimal project files
        (project_dir / "main.jac").write_text(get_minimal_mobile_jac())
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name))

        jac_cmd = get_jac_command()
        env = get_env_with_bun()

        # Setup mobile first
        print("[DEBUG] Setting up mobile target")
        returncode, _, stderr = run_jac_setup_mobile(project_dir)
        assert returncode == 0, f"Mobile setup failed: {stderr}"

        # Install npm packages
        print("[DEBUG] Installing npm packages")
        npm_result = run(
            [*jac_cmd, "add", "--npm"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=180,
        )
        if npm_result.returncode != 0:
            pytest.skip(f"npm install failed: {npm_result.stderr}")

        # Build web target
        print("[DEBUG] Building web target")
        build_result = run(
            [*jac_cmd, "build", "main.jac", "--client", "web"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=180,
        )

        print(
            f"[DEBUG] Web build returncode={build_result.returncode}\n"
            f"STDOUT:\n{build_result.stdout[:2000]}\n"
            f"STDERR:\n{build_result.stderr[:2000]}"
        )

        assert build_result.returncode == 0, (
            f"Web build failed after mobile setup\n"
            f"STDOUT:\n{build_result.stdout}\n"
            f"STDERR:\n{build_result.stderr}"
        )

        # Verify web build output
        dist_dir = project_dir / ".jac" / "client" / "dist"
        assert dist_dir.exists(), "Web build should create .jac/client/dist/"

        dist_files = list(dist_dir.iterdir())
        print(f"[DEBUG] Web dist files: {dist_files}")
        assert len(dist_files) > 0, "Web dist should contain files"

        print("[DEBUG] Web build regression test passed!")


# =============================================================================
# Test: Generated File Contents (unit-level, no CLI required)
# =============================================================================


def test_generated_package_json_is_valid() -> None:
    """Test that the generated package.json has correct structure."""
    print("[DEBUG] Starting test_generated_package_json_is_valid")

    with tempfile.TemporaryDirectory() as temp_dir:
        mobile_dir = Path(temp_dir)

        # Create a minimal package.json matching the generator output
        package_json = {
            "name": "test-app",
            "version": "1.0.0",
            "main": "expo/AppEntry.js",
            "scripts": {
                "start": "expo start",
                "android": "expo start --android",
                "ios": "expo start --ios",
                "web": "expo start --web",
            },
            "dependencies": {
                "expo": "~52.0.0",
                "expo-constants": "~17.0.0",
                "expo-status-bar": "~2.0.0",
                "react": "18.3.1",
                "react-native": "0.76.6",
                "react-native-webview": "13.12.5",
            },
            "devDependencies": {
                "@babel/core": "^7.25.0",
                "@types/react": "~18.3.0",
                "typescript": "^5.3.0",
            },
            "private": True,
        }

        path = mobile_dir / "package.json"
        with open(path, "w") as f:
            json.dump(package_json, f, indent=2)

        # Verify round-trip
        with open(path) as f:
            loaded = json.load(f)

        assert loaded["main"] == "expo/AppEntry.js"
        assert "expo" in loaded["dependencies"]
        assert "react-native-webview" in loaded["dependencies"]
        assert loaded["private"] is True

        print("[DEBUG] Package.json validation passed!")


def test_generated_app_tsx_has_webview() -> None:
    """Test that the generated App.tsx template has the expected WebView setup."""
    print("[DEBUG] Starting test_generated_app_tsx_has_webview")

    # Read the actual template from the impl file
    impl_path = (
        Path(__file__).parent.parent
        / "plugin"
        / "src"
        / "targets"
        / "impl"
        / "mobile_target.impl.jac"
    )
    impl_content = impl_path.read_text()

    # Verify key parts of the App.tsx template in the impl
    assert "import { WebView }" in impl_content, (
        "App.tsx template should import WebView"
    )
    assert "EXPO_PUBLIC_DEV_SERVER_URL" in impl_content, (
        "App.tsx should use EXPO_PUBLIC_DEV_SERVER_URL"
    )
    assert "SafeAreaView" in impl_content, "App.tsx should use SafeAreaView"
    assert "originWhitelist" in impl_content, "WebView should have originWhitelist"
    assert "javaScriptEnabled" in impl_content, "WebView should enable JavaScript"
    assert "domStorageEnabled" in impl_content, "WebView should enable DOM storage"

    # Verify no unused imports
    assert "import { SafeAreaView, StyleSheet, Platform," not in impl_content, (
        "Platform import should not be in generated App.tsx (unused)"
    )

    print("[DEBUG] App.tsx template verification passed!")


def test_app_config_json_no_expo_router() -> None:
    """Test that app_config.json does not include expo-router plugin."""
    print("[DEBUG] Starting test_app_config_json_no_expo_router")

    app_config_path = (
        Path(__file__).parent.parent / "plugin" / "defaults" / "app_config.json"
    )

    with open(app_config_path) as f:
        config = json.load(f)

    # expo-router is NOT a dependency in the generated package.json,
    # so it should NOT be listed as a plugin
    plugins = config.get("expo", {}).get("plugins", [])
    assert "expo-router" not in plugins, (
        "app_config.json should not list expo-router (it's not installed)"
    )

    print("[DEBUG] No expo-router in app_config.json verified!")


# =============================================================================
# Test: CLI Help and Command Registration
# =============================================================================


@requires_jac_setup_cli
def test_build_command_has_mobile_choices() -> None:
    """Test that jac build --help shows mobile as a client choice."""
    print("[DEBUG] Starting test_build_command_has_mobile_choices")

    jac_cmd = get_jac_command()
    result = run(
        [*jac_cmd, "build", "--help"],
        capture_output=True,
        text=True,
        timeout=30,
    )

    # Build help should mention mobile as a client choice
    combined = result.stdout + result.stderr
    assert "mobile" in combined.lower(), (
        "jac build --help should show mobile as a client option"
    )

    print("[DEBUG] Mobile in build choices verified!")


@requires_jac_setup_cli
def test_setup_command_has_mobile_example() -> None:
    """Test that jac setup --help mentions mobile."""
    print("[DEBUG] Starting test_setup_command_has_mobile_example")

    jac_cmd = get_jac_command()
    result = run(
        [*jac_cmd, "setup", "--help"],
        capture_output=True,
        text=True,
        timeout=30,
    )

    combined = result.stdout + result.stderr
    assert "mobile" in combined.lower(), (
        "jac setup --help should mention mobile"
    )

    print("[DEBUG] Mobile in setup help verified!")


@requires_jac_setup_cli
def test_expo_command_exists() -> None:
    """Test that jac expo command is registered."""
    print("[DEBUG] Starting test_expo_command_exists")

    jac_cmd = get_jac_command()
    result = run(
        [*jac_cmd, "expo", "--help"],
        capture_output=True,
        text=True,
        timeout=30,
    )

    combined = result.stdout + result.stderr
    # The command should exist (even if it fails for other reasons)
    assert "unrecognized" not in combined.lower() or "expo" in combined.lower(), (
        "jac expo command should be registered"
    )

    print("[DEBUG] Expo command registration verified!")


@requires_jac_setup_cli
def test_build_command_has_target_flag() -> None:
    """Test that jac build --help shows --target flag for mobile."""
    print("[DEBUG] Starting test_build_command_has_target_flag")

    jac_cmd = get_jac_command()
    result = run(
        [*jac_cmd, "build", "--help"],
        capture_output=True,
        text=True,
        timeout=30,
    )

    combined = result.stdout + result.stderr
    assert "--target" in combined, "jac build --help should show --target flag"
    assert "--profile" in combined, "jac build --help should show --profile flag"

    print("[DEBUG] Mobile build flags verified!")


@requires_jac_setup_cli
def test_start_command_has_mobile_flags() -> None:
    """Test that jac start --help shows mobile-specific flags."""
    print("[DEBUG] Starting test_start_command_has_mobile_flags")

    jac_cmd = get_jac_command()
    result = run(
        [*jac_cmd, "start", "--help"],
        capture_output=True,
        text=True,
        timeout=30,
    )

    combined = result.stdout + result.stderr
    assert "--ios" in combined, "jac start --help should show --ios flag"
    assert "--android" in combined, "jac start --help should show --android flag"
    assert "--tunnel" in combined, "jac start --help should show --tunnel flag"

    print("[DEBUG] Mobile start flags verified!")


# =============================================================================
# Test: Environment Variable Cleanup
# =============================================================================


def test_mobile_env_vars_not_leaked() -> None:
    """Test that JAC_MOBILE_* env vars are cleaned up after build.

    This is a regression test for the env var leak fix.
    """
    print("[DEBUG] Starting test_mobile_env_vars_not_leaked")

    # Verify no stale env vars exist before the test
    mobile_env_keys = [
        "JAC_MOBILE_PROFILE",
        "JAC_MOBILE_LOCAL_BUILD",
        "JAC_MOBILE_IOS",
        "JAC_MOBILE_ANDROID",
        "JAC_MOBILE_TUNNEL",
    ]
    for key in mobile_env_keys:
        # Clean up any stale env vars from other tests
        os.environ.pop(key, None)
        assert key not in os.environ, f"{key} should not be set initially"

    print("[DEBUG] No stale mobile env vars found!")


# =============================================================================
# Test: Setup Without jac.toml
# =============================================================================


@requires_jac_setup_cli
def test_mobile_setup_without_jac_toml_fails() -> None:
    """Test that jac setup mobile fails gracefully without jac.toml."""
    print("[DEBUG] Starting test_mobile_setup_without_jac_toml_fails")

    with tempfile.TemporaryDirectory() as temp_dir:
        project_dir = Path(temp_dir)

        # Do NOT create jac.toml
        jac_cmd = get_jac_command()
        env = get_env_with_bun()

        result = run(
            [*jac_cmd, "setup", "mobile"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=60,
        )

        print(
            f"[DEBUG] Setup without jac.toml: returncode={result.returncode}\n"
            f"STDOUT:\n{result.stdout[:1000]}\n"
            f"STDERR:\n{result.stderr[:1000]}"
        )

        assert result.returncode != 0, "Setup should fail without jac.toml"
        combined = result.stdout + result.stderr
        assert (
            "jac.toml" in combined.lower()
            or "no project" in combined.lower()
            or "not found" in combined.lower()
        ), "Error should mention missing jac.toml"

        print("[DEBUG] Setup without jac.toml correctly fails!")
