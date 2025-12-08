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

            # Verify package.json was created and has correct content
            package_json_path = os.path.join(project_path, "package.json")
            assert os.path.exists(package_json_path)

            with open(package_json_path) as f:
                package_data = json.load(f)

            assert package_data["name"] == test_project_name
            assert package_data["type"] == "module"
            assert "vite" in package_data["devDependencies"]
            assert "build" in package_data["scripts"]
            assert "dev" in package_data["scripts"]
            assert "preview" in package_data["scripts"]

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

            # Verify node_modules was created (npm install ran)
            node_modules_path = os.path.join(project_path, "node_modules")
            assert os.path.exists(node_modules_path)

            # Verify TypeScript files are NOT created
            tsconfig_path = os.path.join(project_path, "tsconfig.json")
            assert not os.path.exists(tsconfig_path)

            components_dir = os.path.join(project_path, "components")
            assert not os.path.exists(components_dir)

            # Verify package.json does NOT have TypeScript dependencies
            assert "typescript" not in package_data["devDependencies"]
            assert "@types/react" not in package_data["devDependencies"]

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
            package_json_path = os.path.join(project_path, "package.json")
            assert os.path.exists(package_json_path)

            with open(package_json_path) as f:
                package_data = json.load(f)

            assert package_data["name"] == test_project_name
            assert package_data["type"] == "module"
            assert "vite" in package_data["devDependencies"]

            # Verify TypeScript dependencies are present
            assert "typescript" in package_data["devDependencies"]
            assert "@types/react" in package_data["devDependencies"]
            assert "@types/react-dom" in package_data["devDependencies"]
            assert "@vitejs/plugin-react" in package_data["devDependencies"]

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
