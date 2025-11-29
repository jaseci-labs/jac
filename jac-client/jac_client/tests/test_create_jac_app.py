"""Test create-jac-app command."""

import json
import os
import tempfile
from subprocess import run


def test_create_jac_app() -> None:
    """Test create-jac-app command."""
    test_project_name = "test-jac-app"

    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            # Change to temp directory
            os.chdir(temp_dir)

            # Run create-jac-app command
            result = run(
                ["jac", "create_jac_app", test_project_name],
                capture_output=True,
                text=True,
                check=True,
            )

            # Check that command succeeded
            assert result.returncode == 0
            assert (
                f"Successfully created Jac application '{test_project_name}'!"
                in result.stdout
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

            # Verify node_modules was created (npm install ran)
            node_modules_path = os.path.join(project_path, "node_modules")
            assert os.path.exists(node_modules_path)

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
            result = run(
                ["jac", "create_jac_app", test_project_name],
                capture_output=True,
                text=True,
            )

            # Should fail with non-zero exit code
            assert result.returncode != 0
            assert f"Directory '{test_project_name}' already exists" in result.stderr

        finally:
            os.chdir(original_cwd)
