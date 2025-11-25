"""Test create-jac-app command."""

import json
import os
import tempfile
from subprocess import run
from unittest import TestCase


class TestCreateJacApp(TestCase):
    """Test create-jac-app command functionality."""

    def test_create_jac_app(self) -> None:
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
                self.assertEqual(result.returncode, 0)
                self.assertIn(
                    f"Successfully created Jac application '{test_project_name}'!",
                    result.stdout,
                )

                # Verify project directory was created
                project_path = os.path.join(temp_dir, test_project_name)
                self.assertTrue(os.path.exists(project_path))
                self.assertTrue(os.path.isdir(project_path))

                # Verify package.json was created and has correct content
                package_json_path = os.path.join(project_path, "package.json")
                self.assertTrue(os.path.exists(package_json_path))

                with open(package_json_path, "r") as f:
                    package_data = json.load(f)

                self.assertEqual(package_data["name"], test_project_name)
                self.assertEqual(package_data["type"], "module")
                self.assertIn("vite", package_data["devDependencies"])
                self.assertIn("build", package_data["scripts"])
                self.assertIn("dev", package_data["scripts"])
                self.assertIn("preview", package_data["scripts"])

                # Verify app.jac file was created
                app_jac_path = os.path.join(project_path, "app.jac")
                self.assertTrue(os.path.exists(app_jac_path))

                with open(app_jac_path, "r") as f:
                    app_jac_content = f.read()

                self.assertIn("app()", app_jac_content)

                # Verify README.md was created
                readme_path = os.path.join(project_path, "README.md")
                self.assertTrue(os.path.exists(readme_path))

                with open(readme_path, "r") as f:
                    readme_content = f.read()

                self.assertIn(f"# {test_project_name}", readme_content)
                self.assertIn("jac serve app.jac", readme_content)

                # Verify node_modules was created (npm install ran)
                node_modules_path = os.path.join(project_path, "node_modules")
                self.assertTrue(os.path.exists(node_modules_path))

            finally:
                # Return to original directory
                os.chdir(original_cwd)

    def test_create_jac_app_invalid_name(self) -> None:
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
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(
                    "Project name must contain only letters, numbers, hyphens, and underscores",
                    result.stderr,
                )

            finally:
                os.chdir(original_cwd)

    def test_create_jac_app_existing_directory(self) -> None:
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
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(
                    f"Directory '{test_project_name}' already exists", result.stderr
                )

            finally:
                os.chdir(original_cwd)
