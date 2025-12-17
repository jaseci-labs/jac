"""Test create-jac-app command."""

import json
import os
import tempfile
from subprocess import PIPE, Popen, run


def test_create_jac_app() -> None:
    """Test create-jac-app command without TypeScript."""
    test_project_name = "test-jac-app"

    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            # Change to temp directory
            os.chdir(temp_dir)

            # Run create-jac-app command with 'n' for TypeScript
            process = Popen(
                ["jac", "create_jac_app", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate(input="n\n")
            result_code = process.returncode

            # Check that command succeeded
            assert result_code == 0
            assert (
                f"Successfully created Jac application '{test_project_name}'!" in stdout
            )

            # Verify project directory was created
            project_path = os.path.join(temp_dir, test_project_name)
            assert os.path.exists(project_path)
            assert os.path.isdir(project_path)

            # Verify app.jac file was created
            app_jac_path = os.path.join(project_path, "app.jac")
            assert os.path.exists(app_jac_path)

            with open(app_jac_path) as f:
                app_jac_content = f.read()

            assert "app()" in app_jac_content

            # Verify README.md was created
            readme_path = os.path.join(project_path, "README.md")
            assert os.path.exists(readme_path)

            with open(readme_path) as f:
                readme_content = f.read()

            assert f"# {test_project_name}" in readme_content
            assert "jac serve app.jac" in readme_content

            # Verify .gitignore was created with correct content
            gitignore_path = os.path.join(project_path, ".gitignore")
            assert os.path.exists(gitignore_path)

            with open(gitignore_path) as f:
                gitignore_content = f.read()

            assert "node_modules" in gitignore_content
            assert "app.session.bak" in gitignore_content
            assert "app.session.dat" in gitignore_content
            assert "app.session.dir" in gitignore_content
            assert "app.session.users.json" in gitignore_content

            components_dir = os.path.join(project_path, "components")
            assert not os.path.exists(components_dir)

        finally:
            # Return to original directory
            os.chdir(original_cwd)


def test_create_jac_app_invalid_name() -> None:
    """Test create-jac-app command with invalid project name."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Test with invalid name containing spaces
            result = run(
                ["jac", "create_jac_app", "invalid name with spaces"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert (
                "Project name must contain only letters, numbers, hyphens, and underscores"
                in result.stderr
            )

        finally:
            os.chdir(original_cwd)


def test_create_jac_app_existing_directory() -> None:
    """Test create-jac-app command when directory already exists."""
    test_project_name = "existing-test-app"

    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create the directory first
            os.makedirs(test_project_name)

            # Try to create app with same name
            # Note: We still need to provide input for the TypeScript prompt,
            # but the command should fail before that due to existing directory
            process = Popen(
                ["jac", "create_jac_app", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate(input="n\n")
            result_code = process.returncode

            # Should fail with non-zero exit code
            assert result_code != 0
            assert f"Directory '{test_project_name}' already exists" in stderr

        finally:
            os.chdir(original_cwd)


def test_create_jac_app_with_typescript() -> None:
    """Test create-jac-app command with TypeScript support."""
    test_project_name = "test-jac-app-ts"

    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            # Change to temp directory
            os.chdir(temp_dir)

            # Run create-jac-app command with 'y' for TypeScript
            process = Popen(
                ["jac", "create_jac_app", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate(input="y\n")
            result_code = process.returncode

            # Check that command succeeded
            assert result_code == 0
            assert (
                f"Successfully created Jac application '{test_project_name}'!" in stdout
            )

            # Verify project directory was created
            project_path = os.path.join(temp_dir, test_project_name)
            assert os.path.exists(project_path)
            assert os.path.isdir(project_path)

            # Verify package.json was created and has TypeScript dependencies
            package_json_path = os.path.join(project_path, "config.json")
            assert os.path.exists(package_json_path)

            with open(package_json_path) as f:
                package_data = json.load(f)

            assert package_data["package"]["name"] == test_project_name

            # Verify tsconfig.json was created
            tsconfig_path = os.path.join(project_path, "tsconfig.json")
            assert os.path.exists(tsconfig_path)

            with open(tsconfig_path) as f:
                tsconfig_content = f.read()

            assert '"jsx": "react-jsx"' in tsconfig_content
            assert '"include": ["components/**/*"]' in tsconfig_content

            # Verify components directory and Button.tsx were created
            components_dir = os.path.join(project_path, "components")
            assert os.path.exists(components_dir)
            assert os.path.isdir(components_dir)

            button_tsx_path = os.path.join(components_dir, "Button.tsx")
            assert os.path.exists(button_tsx_path)

            with open(button_tsx_path) as f:
                button_content = f.read()

            assert "interface ButtonProps" in button_content
            assert "export const Button" in button_content

            # Verify app.jac includes TypeScript import
            app_jac_path = os.path.join(project_path, "app.jac")
            assert os.path.exists(app_jac_path)

            with open(app_jac_path) as f:
                app_jac_content = f.read()

            assert (
                'cl import from ".components/Button.tsx" { Button }' in app_jac_content
            )
            assert "<Button" in app_jac_content

            # Verify README.md includes TypeScript information
            readme_path = os.path.join(project_path, "README.md")
            assert os.path.exists(readme_path)

            with open(readme_path) as f:
                readme_content = f.read()

            assert "TypeScript Support" in readme_content
            assert "components/Button.tsx" in readme_content

        finally:
            # Return to original directory
            os.chdir(original_cwd)


def test_generate_client_config() -> None:
    """Test generate_client_config command creates config.json."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run generate_client_config command
            result = run(
                ["jac", "generate_client_config"],
                capture_output=True,
                text=True,
            )

            # Check that command succeeded
            assert result.returncode == 0
            assert "Successfully created config.json" in result.stdout

            # Verify config.json was created
            config_path = os.path.join(temp_dir, "config.json")
            assert os.path.exists(config_path)

            # Verify config.json has correct structure
            with open(config_path) as f:
                config_data = json.load(f)

            assert "vite" in config_data
            assert "ts" in config_data
            assert "plugins" in config_data["vite"]
            assert "lib_imports" in config_data["vite"]
            assert "build" in config_data["vite"]
            assert "server" in config_data["vite"]
            assert "resolve" in config_data["vite"]

            # Verify default values
            assert config_data["vite"]["plugins"] == []
            assert config_data["vite"]["lib_imports"] == []
            assert config_data["vite"]["build"] == {}
            assert config_data["vite"]["server"] == {}
            assert config_data["vite"]["resolve"] == {}
            assert config_data["ts"] == {}

        finally:
            os.chdir(original_cwd)


def test_generate_client_config_existing_file() -> None:
    """Test generate_client_config command when config.json already exists."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create existing config.json
            existing_config = {"vite": {"plugins": ["existing()"]}}
            config_path = os.path.join(temp_dir, "config.json")
            with open(config_path, "w") as f:
                json.dump(existing_config, f)

            # Run generate_client_config command
            result = run(
                ["jac", "generate_client_config"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert "config.json already exists" in result.stderr

            # Verify existing config was not overwritten
            with open(config_path) as f:
                config_data = json.load(f)
            assert config_data["vite"]["plugins"] == ["existing()"]

        finally:
            os.chdir(original_cwd)


def test_install_without_cl_flag() -> None:
    """Test add command without --cl flag should fail."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run add command without --cl flag
            result = run(
                ["jac", "add", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert "--cl flag is required" in result.stderr

        finally:
            os.chdir(original_cwd)


def test_install_all_packages() -> None:
    """Test add --cl command installs all packages from config.json."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create config.json with some dependencies
            config_data = {
                "vite": {
                    "plugins": [],
                    "lib_imports": [],
                    "build": {},
                    "server": {},
                    "resolve": {},
                },
                "ts": {},
                "package": {
                    "name": "test-project",
                    "version": "1.0.0",
                    "description": "Test project",
                    "dependencies": {"lodash": "^4.17.21"},
                    "devDependencies": {},
                },
            }
            config_path = os.path.join(temp_dir, "config.json")
            with open(config_path, "w") as f:
                json.dump(config_data, f)

            # Run add --cl command without package name
            result = run(
                ["jac", "add", "--cl"],
                capture_output=True,
                text=True,
            )

            # Should succeed
            assert result.returncode == 0
            assert "Installing all packages from config.json" in result.stdout
            assert "Successfully installed all packages" in result.stdout

        finally:
            os.chdir(original_cwd)


def test_install_package_to_dependencies() -> None:
    """Test add --cl command adds package to dependencies."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create config.json
            config_data = {
                "vite": {
                    "plugins": [],
                    "lib_imports": [],
                    "build": {},
                    "server": {},
                    "resolve": {},
                },
                "ts": {},
                "package": {
                    "name": "test-project",
                    "version": "1.0.0",
                    "description": "Test project",
                    "dependencies": {},
                    "devDependencies": {},
                },
            }
            config_path = os.path.join(temp_dir, "config.json")
            with open(config_path, "w") as f:
                json.dump(config_data, f)

            # Run add --cl command with package name
            result = run(
                ["jac", "add", "--cl", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should succeed
            assert result.returncode == 0
            assert "Added lodash to dependencies" in result.stdout

            # Verify package was added to config.json
            with open(config_path) as f:
                updated_config = json.load(f)

            assert "lodash" in updated_config["package"]["dependencies"]
            assert "lodash" not in updated_config["package"]["devDependencies"]

        finally:
            os.chdir(original_cwd)


def test_install_package_with_version() -> None:
    """Test add --cl command with specific version."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create config.json
            config_data = {
                "vite": {
                    "plugins": [],
                    "lib_imports": [],
                    "build": {},
                    "server": {},
                    "resolve": {},
                },
                "ts": {},
                "package": {
                    "name": "test-project",
                    "version": "1.0.0",
                    "description": "Test project",
                    "dependencies": {},
                    "devDependencies": {},
                },
            }
            config_path = os.path.join(temp_dir, "config.json")
            with open(config_path, "w") as f:
                json.dump(config_data, f)

            # Run add --cl command with package and version
            result = run(
                ["jac", "add", "--cl", "lodash@^4.17.21"],
                capture_output=True,
                text=True,
            )

            # Should succeed
            assert result.returncode == 0
            assert "Added lodash@^4.17.21 to dependencies" in result.stdout

            # Verify package was added with correct version
            with open(config_path) as f:
                updated_config = json.load(f)

            assert updated_config["package"]["dependencies"]["lodash"] == "^4.17.21"

        finally:
            os.chdir(original_cwd)


def test_install_package_to_devdependencies() -> None:
    """Test add --cl -D command adds package to devDependencies."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create config.json
            config_data = {
                "vite": {
                    "plugins": [],
                    "lib_imports": [],
                    "build": {},
                    "server": {},
                    "resolve": {},
                },
                "ts": {},
                "package": {
                    "name": "test-project",
                    "version": "1.0.0",
                    "description": "Test project",
                    "dependencies": {},
                    "devDependencies": {},
                },
            }
            config_path = os.path.join(temp_dir, "config.json")
            with open(config_path, "w") as f:
                json.dump(config_data, f)

            # Run add --cl -D command
            run(
                ["jac", "add", "--cl", "-d", "@types/react"],
                capture_output=True,
                text=True,
            )

            # Verify package was added to devDependencies in config.json
            # (config.json is updated before npm install, so check it even if npm fails)
            with open(config_path) as f:
                updated_config = json.load(f)

            assert "@types/react" in updated_config["package"]["devDependencies"]
            assert "@types/react" not in updated_config["package"]["dependencies"]

            # Note: npm install might fail in test environment, but config.json should still be updated
            # The important part is that the package was added to the correct section in config.json

        finally:
            os.chdir(original_cwd)


def test_install_without_config_json() -> None:
    """Test add --cl command when config.json doesn't exist."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run add --cl command without config.json
            result = run(
                ["jac", "add", "--cl", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert "config.json not found" in result.stderr

        finally:
            os.chdir(original_cwd)


def test_uninstall_without_cl_flag() -> None:
    """Test remove command without --cl flag should fail."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run remove command without --cl flag
            result = run(
                ["jac", "remove", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert "--cl flag is required" in result.stderr

        finally:
            os.chdir(original_cwd)


def test_uninstall_without_package_name() -> None:
    """Test remove --cl command without package name should fail."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create config.json
            config_data = {
                "vite": {
                    "plugins": [],
                    "lib_imports": [],
                    "build": {},
                    "server": {},
                    "resolve": {},
                },
                "ts": {},
                "package": {
                    "name": "test-project",
                    "version": "1.0.0",
                    "description": "Test project",
                    "dependencies": {},
                    "devDependencies": {},
                },
            }
            config_path = os.path.join(temp_dir, "config.json")
            with open(config_path, "w") as f:
                json.dump(config_data, f)

            # Run remove --cl command without package name
            result = run(
                ["jac", "remove", "--cl"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert "Package name is required" in result.stderr

        finally:
            os.chdir(original_cwd)


def test_uninstall_package_from_dependencies() -> None:
    """Test remove --cl command removes package from dependencies."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create config.json with a package
            config_data = {
                "vite": {
                    "plugins": [],
                    "lib_imports": [],
                    "build": {},
                    "server": {},
                    "resolve": {},
                },
                "ts": {},
                "package": {
                    "name": "test-project",
                    "version": "1.0.0",
                    "description": "Test project",
                    "dependencies": {"lodash": "^4.17.21"},
                    "devDependencies": {},
                },
            }
            config_path = os.path.join(temp_dir, "config.json")
            with open(config_path, "w") as f:
                json.dump(config_data, f)

            # Run remove --cl command
            result = run(
                ["jac", "remove", "--cl", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should succeed
            assert result.returncode == 0
            assert "Removed lodash from dependencies" in result.stdout

            # Verify package was removed from config.json
            with open(config_path) as f:
                updated_config = json.load(f)

            assert "lodash" not in updated_config["package"]["dependencies"]

        finally:
            os.chdir(original_cwd)


def test_uninstall_package_from_devdependencies() -> None:
    """Test remove --cl -D command removes package from devDependencies."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create config.json with a devDependency
            config_data = {
                "vite": {
                    "plugins": [],
                    "lib_imports": [],
                    "build": {},
                    "server": {},
                    "resolve": {},
                },
                "ts": {},
                "package": {
                    "name": "test-project",
                    "version": "1.0.0",
                    "description": "Test project",
                    "dependencies": {},
                    "devDependencies": {"@types/react": "^18.0.0"},
                },
            }
            config_path = os.path.join(temp_dir, "config.json")
            with open(config_path, "w") as f:
                json.dump(config_data, f)

            # Run remove --cl -D command
            result = run(
                ["jac", "remove", "--cl", "-d", "@types/react"],
                capture_output=True,
                text=True,
            )

            # Should succeed
            assert result.returncode == 0
            assert "Removed @types/react from devDependencies" in result.stdout

            # Verify package was removed from config.json
            with open(config_path) as f:
                updated_config = json.load(f)

            assert "@types/react" not in updated_config["package"]["devDependencies"]

        finally:
            os.chdir(original_cwd)


def test_uninstall_nonexistent_package() -> None:
    """Test remove --cl command with non-existent package should fail."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Create config.json without the package
            config_data = {
                "vite": {
                    "plugins": [],
                    "lib_imports": [],
                    "build": {},
                    "server": {},
                    "resolve": {},
                },
                "ts": {},
                "package": {
                    "name": "test-project",
                    "version": "1.0.0",
                    "description": "Test project",
                    "dependencies": {},
                    "devDependencies": {},
                },
            }
            config_path = os.path.join(temp_dir, "config.json")
            with open(config_path, "w") as f:
                json.dump(config_data, f)

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


def test_uninstall_without_config_json() -> None:
    """Test remove --cl command when config.json doesn't exist."""
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # Run remove --cl command without config.json
            result = run(
                ["jac", "remove", "--cl", "lodash"],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert "config.json not found" in result.stderr

        finally:
            os.chdir(original_cwd)
