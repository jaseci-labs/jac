"""Test create-jac-app command."""

import os
import tempfile
import tomllib
from subprocess import PIPE, Popen, run


def test_create_jac_app() -> None:
    """Test jac create --cl command."""
    test_project_name = "test-jac-app"

    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            # Change to temp directory
            os.chdir(temp_dir)

            # Run jac create --cl command
            process = Popen(
                ["jac", "create", "--cl", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate()
            result_code = process.returncode

            # Check that command succeeded
            assert result_code == 0
            assert f"Project '{test_project_name}' created successfully!" in stdout

            # Verify project directory was created
            project_path = os.path.join(temp_dir, test_project_name)
            assert os.path.exists(project_path)
            assert os.path.isdir(project_path)

            # Verify main.jac file was created at project root
            app_jac_path = os.path.join(project_path, "main.jac")
            assert os.path.exists(app_jac_path)

            with open(app_jac_path) as f:
                app_jac_content = f.read()

            assert "def:pub app()" in app_jac_content

            # Verify README.md was created
            readme_path = os.path.join(project_path, "README.md")
            assert os.path.exists(readme_path)

            with open(readme_path) as f:
                readme_content = f.read()

            assert f"# {test_project_name}" in readme_content
            assert "jac start main.jac" in readme_content

            # Verify jac.toml was created
            jac_toml_path = os.path.join(project_path, "jac.toml")
            assert os.path.exists(jac_toml_path)

            with open(jac_toml_path, "rb") as f:
                config_data = tomllib.load(f)

            assert config_data["project"]["name"] == test_project_name

            # Verify serve config includes base_route_app for CL apps
            assert "serve" in config_data
            assert config_data["serve"]["base_route_app"] == "app"

            # Verify .gitignore was created with correct content
            gitignore_path = os.path.join(project_path, ".gitignore")
            assert os.path.exists(gitignore_path)

            with open(gitignore_path) as f:
                gitignore_content = f.read()

            assert "node_modules" in gitignore_content

            # Verify components directory exists at project root
            components_dir = os.path.join(project_path, "components")
            assert os.path.exists(components_dir)

            # Verify default packages installation (package.json should be generated)
            package_json_path = os.path.join(
                project_path, ".jac", "client", "configs", "package.json"
            )
            # Note: packages may or may not be installed depending on npm availability
            # but package.json should be generated with default packages
            if os.path.exists(package_json_path):
                import json

                with open(package_json_path) as f:
                    package_data = json.load(f)

                # Verify default dependencies are in package.json
                assert "jac-client-node" in package_data.get("dependencies", {})
                assert "@jac-client/dev-deps" in package_data.get("devDependencies", {})

        finally:
            # Return to original directory
            os.chdir(original_cwd)


def test_create_jac_app_invalid_name() -> None:
    """Test jac create --cl command with project names containing spaces.

    Note: The current implementation allows names with spaces. This test
    verifies that such projects are created successfully.
    """
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Test with name containing spaces (currently allowed)
            result = run(
                ["jac", "create", "--cl", "--skip", "name with spaces"],
                capture_output=True,
                text=True,
            )

            # Currently succeeds - names with spaces are allowed
            assert result.returncode == 0
            assert "Project 'name with spaces' created successfully!" in result.stdout

        finally:
            os.chdir(original_cwd)


def test_create_jac_app_existing_directory() -> None:
    """Test jac create --cl command when directory already exists."""
    test_project_name = "existing-test-app"

    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create the directory first
            os.makedirs(test_project_name)

            # Try to create app with same name
            process = Popen(
                ["jac", "create", "--cl", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate()
            result_code = process.returncode

            # Should fail with non-zero exit code
            assert result_code != 0
            assert f"Directory '{test_project_name}' already exists" in stderr

        finally:
            os.chdir(original_cwd)


def test_create_jac_app_with_button_component() -> None:
    """Test jac create --cl command creates Button.cl.jac component."""
    test_project_name = "test-jac-app-component"

    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            # Change to temp directory
            os.chdir(temp_dir)

            # Run jac create --cl command
            process = Popen(
                ["jac", "create", "--cl", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate()
            result_code = process.returncode

            # Check that command succeeded
            assert result_code == 0
            assert f"Project '{test_project_name}' created successfully!" in stdout

            # Verify project directory was created
            project_path = os.path.join(temp_dir, test_project_name)
            assert os.path.exists(project_path)
            assert os.path.isdir(project_path)

            # Verify jac.toml was created
            jac_toml_path = os.path.join(project_path, "jac.toml")
            assert os.path.exists(jac_toml_path)

            with open(jac_toml_path, "rb") as f:
                config_data = tomllib.load(f)

            assert config_data["project"]["name"] == test_project_name

            # Verify serve config includes base_route_app for CL apps
            assert "serve" in config_data
            assert config_data["serve"]["base_route_app"] == "app"

            # Verify components directory and Button.cl.jac were created at project root
            components_dir = os.path.join(project_path, "components")
            assert os.path.exists(components_dir)
            assert os.path.isdir(components_dir)

            button_jac_path = os.path.join(components_dir, "Button.cl.jac")
            assert os.path.exists(button_jac_path)

            with open(button_jac_path) as f:
                button_content = f.read()

            assert "def:pub Button" in button_content
            assert "base_styles" in button_content

            # Verify main.jac includes Jac component import
            app_jac_path = os.path.join(project_path, "main.jac")
            assert os.path.exists(app_jac_path)

            with open(app_jac_path) as f:
                app_jac_content = f.read()

            assert "cl import from .components.Button { Button }" in app_jac_content
            assert "<Button" in app_jac_content

            # Verify README.md includes component information
            readme_path = os.path.join(project_path, "README.md")
            assert os.path.exists(readme_path)

            with open(readme_path) as f:
                readme_content = f.read()

            assert "Components" in readme_content
            assert "Button.cl.jac" in readme_content

            # Verify default packages installation (package.json should be generated)
            package_json_path = os.path.join(
                project_path, ".jac", "client", "configs", "package.json"
            )
            # Note: packages may or may not be installed depending on npm availability
            # but package.json should be generated with default packages
            if os.path.exists(package_json_path):
                import json

                with open(package_json_path) as f:
                    package_data = json.load(f)

                # Verify default dependencies are in package.json
                assert "jac-client-node" in package_data.get("dependencies", {})
                assert "@jac-client/dev-deps" in package_data.get("devDependencies", {})

        finally:
            # Return to original directory
            os.chdir(original_cwd)


def test_create_jac_app_with_skip_flag() -> None:
    """Test jac create --cl --skip command skips package installation."""
    test_project_name = "test-jac-app-skip"

    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            # Change to temp directory
            os.chdir(temp_dir)

            # Run jac create --cl --skip command
            process = Popen(
                ["jac", "create", "--cl", "--skip", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate()
            result_code = process.returncode

            # Check that command succeeded
            assert result_code == 0
            assert f"Project '{test_project_name}' created successfully!" in stdout

            # Verify project directory was created
            project_path = os.path.join(temp_dir, test_project_name)
            assert os.path.exists(project_path)
            assert os.path.isdir(project_path)

            # Verify that "Installing default packages" message is NOT in output
            assert "Installing default packages" not in stdout
            assert "Default packages installed successfully" not in stdout

            # Verify jac.toml was created
            jac_toml_path = os.path.join(project_path, "jac.toml")
            assert os.path.exists(jac_toml_path)

        finally:
            # Return to original directory
            os.chdir(original_cwd)


def test_create_jac_app_installs_default_packages() -> None:
    """Test jac create --cl command attempts to install default packages."""
    test_project_name = "test-jac-app-install"

    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            # Change to temp directory
            os.chdir(temp_dir)

            # Run jac create --cl command
            process = Popen(
                ["jac", "create", "--cl", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate()
            result_code = process.returncode

            # Check that command succeeded
            assert result_code == 0
            assert f"Project '{test_project_name}' created successfully!" in stdout

            # Verify project directory was created
            project_path = os.path.join(temp_dir, test_project_name)
            assert os.path.exists(project_path)

            # Verify that installation was attempted (message should be in output)
            assert "Installing default npm packages" in stdout

            # Verify package.json was generated (even if npm install failed)
            package_json_path = os.path.join(
                project_path, ".jac", "client", "configs", "package.json"
            )
            # package.json should be generated with default packages
            if os.path.exists(package_json_path):
                import json

                with open(package_json_path) as f:
                    package_data = json.load(f)

                # Verify default dependencies are in package.
                assert "jac-client-node" in package_data.get("dependencies", {})
                assert "@jac-client/dev-deps" in package_data.get("devDependencies", {})

        finally:
            # Return to original directory
            os.chdir(original_cwd)


def test_generate_client_config() -> None:
    """Test that generate_client_config command no longer exists (use jac init instead)."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run generate_client_config command - should not exist
            result = run(
                ["jac", "generate_client_config"],
                capture_output=True,
                text=True,
            )

            # Command should not exist anymore
            assert result.returncode != 0

        finally:
            os.chdir(original_cwd)


def test_generate_client_config_existing_file() -> None:
    """Test that generate_client_config command no longer exists."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run generate_client_config command - should not exist
            result = run(
                ["jac", "generate_client_config"],
                capture_output=True,
                text=True,
            )

            # Command should not exist anymore
            assert result.returncode != 0

        finally:
            os.chdir(original_cwd)


def _create_jac_toml(temp_dir: str, deps: str = "", dev_deps: str = "") -> str:
    """Create a minimal jac.toml file for testing.

    Note: These CLI tests run jac commands as subprocesses and include npm install.
    For faster tests, consider using unit tests with mocked PackageInstaller.
    """
    deps_section = f"\n{deps}" if deps else ""
    dev_deps_section = f"\n{dev_deps}" if dev_deps else ""

    toml_content = f"""[project]
name = "test-project"
version = "1.0.0"
description = "Test project"
entry-point = "app.jac"

[dependencies.npm]{deps_section}

[dev-dependencies.npm]{dev_deps_section}
"""
    config_path = os.path.join(temp_dir, "jac.toml")
    with open(config_path, "w") as f:
        f.write(toml_content)
    return config_path


def test_install_without_cl_flag() -> None:
    """Test add command without --cl flag should skip silently when no jac.toml exists."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run add command without --cl flag and without jac.toml
            result = run(
                ["jac", "add", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should skip silently (return 0) when no jac.toml exists
            assert result.returncode == 0
            # No error message should be printed
            assert "No jac.toml found" not in result.stderr
            assert "No jac.toml found" not in result.stdout

        finally:
            os.chdir(original_cwd)


def test_install_all_packages() -> None:
    """Test add --cl command installs all packages from jac.toml."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create jac.toml with some dependencies
            _create_jac_toml(temp_dir, deps='lodash = "^4.17.21"')

            # Run add --cl command without package name
            result = run(
                ["jac", "add", "--cl"],
                capture_output=True,
                text=True,
            )

            # Should succeed
            assert result.returncode == 0
            assert "Installing all npm packages" in result.stdout
            assert "Installed all npm packages successfully" in result.stdout

        finally:
            os.chdir(original_cwd)


def test_install_package_to_dependencies() -> None:
    """Test add --cl command adds package to dependencies."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create jac.toml
            config_path = _create_jac_toml(temp_dir)

            # Run add --cl command with package name
            result = run(
                ["jac", "add", "--cl", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should succeed
            assert result.returncode == 0
            assert "Adding lodash (npm)" in result.stdout
            assert "Added 1 package(s) to [dependencies.npm]" in result.stdout

            # Verify package was added to jac.toml
            with open(config_path, "rb") as f:
                updated_config = tomllib.load(f)

            assert "lodash" in updated_config["dependencies"]["npm"]

        finally:
            os.chdir(original_cwd)


def test_install_package_with_version() -> None:
    """Test add --cl command with specific version."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create jac.toml
            config_path = _create_jac_toml(temp_dir)

            # Run add --cl command with package and version
            result = run(
                ["jac", "add", "--cl", "lodash@^4.17.21"],
                capture_output=True,
                text=True,
            )

            # Should succeed
            assert result.returncode == 0
            assert "Adding lodash (npm)" in result.stdout
            assert "Added 1 package(s) to [dependencies.npm]" in result.stdout

            # Verify package was added with correct version
            with open(config_path, "rb") as f:
                updated_config = tomllib.load(f)

            assert updated_config["dependencies"]["npm"]["lodash"] == "^4.17.21"

        finally:
            os.chdir(original_cwd)


def test_install_package_to_devdependencies() -> None:
    """Test add --cl -d command adds package to dev-dependencies."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create jac.toml
            config_path = _create_jac_toml(temp_dir)

            # Run add --cl -d command
            run(
                ["jac", "add", "--cl", "-d", "@types/react"],
                capture_output=True,
                text=True,
            )

            # Verify package was added to dev-dependencies in jac.toml
            with open(config_path, "rb") as f:
                updated_config = tomllib.load(f)

            npm_deps = updated_config["dependencies"]["npm"]
            assert "@types/react" in npm_deps.get("dev", {})
            # Check it's not in regular deps (excluding the "dev" key)
            regular_deps = {k: v for k, v in npm_deps.items() if k != "dev"}
            assert "@types/react" not in regular_deps

        finally:
            os.chdir(original_cwd)


def test_install_without_config_json() -> None:
    """Test add --cl command when jac.toml doesn't exist."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run add --cl command without jac.toml
            result = run(
                ["jac", "add", "--cl", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert "No jac.toml found" in result.stderr

        finally:
            os.chdir(original_cwd)


def test_uninstall_without_cl_flag() -> None:
    """Test remove command without --cl flag should fail when no jac.toml exists."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run remove command without --cl flag and without jac.toml
            result = run(
                ["jac", "remove", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code because no jac.toml
            assert result.returncode != 0
            assert "No jac.toml found" in result.stderr

        finally:
            os.chdir(original_cwd)


def test_uninstall_without_package_name() -> None:
    """Test remove --cl command without package name should fail."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create jac.toml
            _create_jac_toml(temp_dir)

            # Run remove --cl command without package name
            result = run(
                ["jac", "remove", "--cl"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert "No packages specified" in result.stderr

        finally:
            os.chdir(original_cwd)


def test_uninstall_package_from_dependencies() -> None:
    """Test remove --cl command removes package from dependencies."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create jac.toml with a package
            config_path = _create_jac_toml(temp_dir, deps='lodash = "^4.17.21"')

            # Run remove --cl command
            result = run(
                ["jac", "remove", "--cl", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should succeed
            assert result.returncode == 0
            assert "Removing lodash (npm)" in result.stdout
            assert "Removed 1 package(s)" in result.stdout

            # Verify package was removed from jac.toml
            with open(config_path, "rb") as f:
                updated_config = tomllib.load(f)

            npm_deps = updated_config.get("dependencies", {}).get("npm", {})
            regular_deps = {k: v for k, v in npm_deps.items() if k != "dev"}
            assert "lodash" not in regular_deps

        finally:
            os.chdir(original_cwd)


def test_uninstall_package_from_devdependencies() -> None:
    """Test remove --cl -d command removes package from dev-dependencies."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create jac.toml with a dev-dependency
            config_path = _create_jac_toml(
                temp_dir, dev_deps='"@types/react" = "^18.0.0"'
            )

            # Run remove --cl -d command
            result = run(
                ["jac", "remove", "--cl", "-d", "@types/react"],
                capture_output=True,
                text=True,
            )

            # Should succeed
            assert result.returncode == 0
            assert "Removing @types/react (npm)" in result.stdout
            assert "Removed 1 package(s)" in result.stdout

            # Verify package was removed from jac.toml
            with open(config_path, "rb") as f:
                updated_config = tomllib.load(f)

            npm_deps = updated_config.get("dependencies", {}).get("npm", {})
            assert "@types/react" not in npm_deps.get("dev", {})

        finally:
            os.chdir(original_cwd)


def test_uninstall_nonexistent_package() -> None:
    """Test remove --cl command with non-existent package should fail."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create jac.toml without the package
            _create_jac_toml(temp_dir)

            # Run remove --cl command with non-existent package
            result = run(
                ["jac", "remove", "--cl", "nonexistent-package"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert "not found" in result.stderr.lower()

        finally:
            os.chdir(original_cwd)


def test_uninstall_without_config_toml() -> None:
    """Test remove --cl command when jac.toml doesn't exist."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run remove --cl command without jac.toml
            result = run(
                ["jac", "remove", "--cl", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert "No jac.toml found" in result.stderr

        finally:
            os.chdir(original_cwd)


def test_create_cl_and_run_no_root_files() -> None:
    """Test that jac create --cl + jac run doesn't create files outside .jac/ directory."""
    test_project_name = "test-cl-no-root-files"

    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run jac create --cl command
            process = Popen(
                ["jac", "create", "--cl", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate()
            assert process.returncode == 0, f"jac create --cl failed: {stderr}"

            project_path = os.path.join(temp_dir, test_project_name)

            # Record files after create (before run), excluding .jac directory
            def get_root_files(path: str) -> set[str]:
                """Get files/dirs in project root, excluding .jac directory."""
                items = set()
                for item in os.listdir(path):
                    if item != ".jac":
                        items.add(item)
                return items

            files_before_run = get_root_files(project_path)

            # Run jac run main.jac
            process = Popen(
                ["jac", "run", "main.jac"],
                cwd=project_path,
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate()
            assert process.returncode == 0, f"jac run failed: {stderr}"

            # Record files after run
            files_after_run = get_root_files(project_path)

            # Check no new files were created in project root
            new_files = files_after_run - files_before_run
            assert not new_files, (
                f"jac run created unexpected files in project root: {new_files}. "
                "All runtime files should be in .jac/ directory."
            )

        finally:
            os.chdir(original_cwd)
