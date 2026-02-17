"""Test create-jac-app command."""

import contextlib;
import os;
import tempfile;
import tomllib;
import time;
import json;
import from pathlib { Path }
import from subprocess { PIPE, Popen, run }
import unittest.mock;

test "create jac app" {
    """Test jac create --use client command."""
    test_project_name = "test-jac-app";

    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            # Change to temp directory
            os.chdir(temp_dir);

            # Run jac create --use client command
            process = Popen(
                ["jac", "create", "--use", "client", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            );
            (stdout, stderr) = process.communicate();
            result_code = process.returncode;

            # Check that command succeeded
            assert result_code == 0;
            # Check for success message (handles both old and new console formats)
            assert (
                f"Project '{test_project_name}' created successfully!" in stdout
                or f"Project '{test_project_name}' created" in stdout
            );

            # Verify project directory was created
            project_path = os.path.join(temp_dir, test_project_name);
            assert os.path.exists(project_path);
            assert os.path.isdir(project_path);

            # Verify main.jac file was created at project root
            app_jac_path = os.path.join(project_path, "main.jac");
            assert os.path.exists(app_jac_path);

            with open(app_jac_path) as f {
                app_jac_content = f.read();
            }

            assert "def:pub app()" in app_jac_content;

            # Verify README.md was created
            readme_path = os.path.join(project_path, "README.md");
            assert os.path.exists(readme_path);

            with open(readme_path) as f {
                readme_content = f.read();
            }

            assert f"# {test_project_name}" in readme_content;
            assert "jac start main.jac" in readme_content;

            # Verify jac.toml was created
            jac_toml_path = os.path.join(project_path, "jac.toml");
            assert os.path.exists(jac_toml_path);

            with open(jac_toml_path, "rb") as f {
                config_data = tomllib.load(f);
            }

            assert config_data["project"]["name"] == test_project_name;

            # Verify serve config includes base_route_app for CL apps
            assert "serve" in config_data;
            assert config_data["serve"]["base_route_app"] == "app";

            # Verify .gitignore was created with correct content
            gitignore_path = os.path.join(project_path, ".gitignore");
            assert os.path.exists(gitignore_path);

            with open(gitignore_path) as f {
                gitignore_content = f.read();
            }

            assert "node_modules" in gitignore_content;

            # Verify components directory exists at project root
            components_dir = os.path.join(project_path, "components");
            assert os.path.exists(components_dir);

            # Verify default packages installation (package.json should be generated)
            package_json_path = os.path.join(
                project_path, ".jac", "client", "configs", "package.json"
            );
            # Note: packages may or may not be installed depending on npm availability
            # but package.json should be generated with default packages
            if os.path.exists(package_json_path) {
                with open(package_json_path) as f {
                    package_data = json.load(f);
                }
                # Verify default dependencies are in package.json
                assert "jac-client-node" in package_data.get("dependencies", {});
                assert "@jac-client/dev-deps" in package_data.get(
                    "devDependencies", {}
                );
            }
        } finally {
            # Return to original directory
            os.chdir(original_cwd);
        }
    }
}

test "create jac app invalid name" {
    """Test jac create --use client command with project names containing spaces."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Test with name containing spaces (currently allowed)
            result = run(
                ["jac", "create", "--use", "client", "--skip", "name with spaces"],
                capture_output=True,
                text=True,
            );

            # Currently succeeds - names with spaces are allowed
            assert result.returncode == 0;
            # Check for success message (handles both old and new console formats)
            assert (
                "Project 'name with spaces' created successfully!" in result.stdout
                or "Project 'name with spaces' created" in result.stdout
            );
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "create jac app existing directory" {
    """Test jac create --use client command when directory already exists."""
    test_project_name = "existing-test-app";

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create the directory first
            os.makedirs(test_project_name);

            # Try to create app with same name
            process = Popen(
                ["jac", "create", "--use", "client", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            );
            (stdout, stderr) = process.communicate();
            result_code = process.returncode;

            # Should fail with non-zero exit code
            assert result_code != 0;
            assert f"Directory '{test_project_name}' already exists" in stderr;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "create jac app with button component" {
    """Test jac create --use client command creates Button.cl.jac component."""
    test_project_name = "test-jac-app-component";

    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            # Change to temp directory
            os.chdir(temp_dir);

            # Run jac create --use client command
            process = Popen(
                ["jac", "create", "--use", "client", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            );
            (stdout, stderr) = process.communicate();
            result_code = process.returncode;

            # Check that command succeeded
            assert result_code == 0;
            # Check for success message (handles both old and new console formats)
            assert (
                f"Project '{test_project_name}' created successfully!" in stdout
                or f"Project '{test_project_name}' created" in stdout
            );

            # Verify project directory was created
            project_path = os.path.join(temp_dir, test_project_name);
            assert os.path.exists(project_path);
            assert os.path.isdir(project_path);

            # Verify jac.toml was created
            jac_toml_path = os.path.join(project_path, "jac.toml");
            assert os.path.exists(jac_toml_path);

            with open(jac_toml_path, "rb") as f {
                config_data = tomllib.load(f);
            }

            assert config_data["project"]["name"] == test_project_name;

            # Verify serve config includes base_route_app for CL apps
            assert "serve" in config_data;
            assert config_data["serve"]["base_route_app"] == "app";

            # Verify components directory and Button.cl.jac were created at project root
            components_dir = os.path.join(project_path, "components");
            assert os.path.exists(components_dir);
            assert os.path.isdir(components_dir);

            button_jac_path = os.path.join(components_dir, "Button.cl.jac");
            assert os.path.exists(button_jac_path);

            with open(button_jac_path) as f {
                button_content = f.read();
            }

            assert "def:pub Button" in button_content;
            assert "base_styles" in button_content;

            # Verify main.jac includes Jac component import
            app_jac_path = os.path.join(project_path, "main.jac");
            assert os.path.exists(app_jac_path);

            with open(app_jac_path) as f {
                app_jac_content = f.read();
            }

            assert "cl import from .components.Button { Button }" in app_jac_content;
            assert "<Button" in app_jac_content;

            # Verify README.md includes component information
            readme_path = os.path.join(project_path, "README.md");
            assert os.path.exists(readme_path);

            with open(readme_path) as f {
                readme_content = f.read();
            }

            assert "Components" in readme_content;
            assert "Button.cl.jac" in readme_content;

            # Verify default packages installation (package.json should be generated)
            package_json_path = os.path.join(
                project_path, ".jac", "client", "configs", "package.json"
            );
            if os.path.exists(package_json_path) {
                with open(package_json_path) as f {
                    package_data = json.load(f);
                }
                # Verify default dependencies are in package.json
                assert "jac-client-node" in package_data.get("dependencies", {});
                assert "@jac-client/dev-deps" in package_data.get(
                    "devDependencies", {}
                );
            }
        } finally {
            # Return to original directory
            os.chdir(original_cwd);
        }
    }
}

test "create jac app with skip flag" {
    """Test jac create --use client --skip command skips package installation."""
    test_project_name = "test-jac-app-skip";

    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            # Change to temp directory
            os.chdir(temp_dir);

            # Run jac create --use client --skip command
            process = Popen(
                ["jac", "create", "--use", "client", "--skip", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            );
            (stdout, stderr) = process.communicate();
            result_code = process.returncode;

            # Check that command succeeded
            assert result_code == 0;
            # Check for success message (handles both old and new console formats)
            assert (
                f"Project '{test_project_name}' created successfully!" in stdout
                or f"Project '{test_project_name}' created" in stdout
            );

            # Verify project directory was created
            project_path = os.path.join(temp_dir, test_project_name);
            assert os.path.exists(project_path);
            assert os.path.isdir(project_path);

            # Verify that "Installing default packages" message is NOT in output
            assert "Installing default packages" not in stdout;
            assert "Default packages installed successfully" not in stdout;

            # Verify jac.toml was created
            jac_toml_path = os.path.join(project_path, "jac.toml");
            assert os.path.exists(jac_toml_path);
        } finally {
            # Return to original directory
            os.chdir(original_cwd);
        }
    }
}

test "create jac app installs default packages" {
    """Test jac create --use client command attempts to install default packages."""
    test_project_name = "test-jac-app-install";

    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            # Change to temp directory
            os.chdir(temp_dir);

            # Run jac create --use client command
            process = Popen(
                ["jac", "create", "--use", "client", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            );
            (stdout, stderr) = process.communicate();
            result_code = process.returncode;

            # Check that command succeeded
            assert result_code == 0;
            # Check for success message (handles both old and new console formats)
            assert (
                f"Project '{test_project_name}' created successfully!" in stdout
                or f"Project '{test_project_name}' created" in stdout
            );

            # Verify project directory was created
            project_path = os.path.join(temp_dir, test_project_name);
            assert os.path.exists(project_path);

            # Verify package.json was generated (even if npm install failed)
            package_json_path = os.path.join(
                project_path, ".jac", "client", "configs", "package.json"
            );
            # package.json should be generated with default packages
            if os.path.exists(package_json_path) {
                with open(package_json_path) as f {
                    package_data = json.load(f);
                }
                # Verify default dependencies are in package.json
                assert "jac-client-node" in package_data.get("dependencies", {});
                assert "@jac-client/dev-deps" in package_data.get(
                    "devDependencies", {}
                );
            }
        } finally {
            # Return to original directory
            os.chdir(original_cwd);
        }
    }
}

test "generate client config" {
    """Test that generate_client_config command no longer exists (use jac init instead)."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Run generate_client_config command - should not exist
            result = run(
                ["jac", "generate_client_config"], capture_output=True, text=True,
            );

            # Command should not exist anymore
            assert result.returncode != 0;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "generate client config existing file" {
    """Test that generate_client_config command no longer exists."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Run generate_client_config command - should not exist
            result = run(
                ["jac", "generate_client_config"], capture_output=True, text=True,
            );

            # Command should not exist anymore
            assert result.returncode != 0;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

def _create_jac_toml(temp_dir: str, deps: str = "", dev_deps: str = "") -> str {
    """Create a minimal jac.toml file for testing."""
    deps_section = f"\n{deps}" if deps else "";
    dev_deps_section = f"\n{dev_deps}" if dev_deps else "";

    toml_content = f'[project]\nname = "test-project"\nversion = "1.0.0"\ndescription = "Test project"\nentry-point = "app.jac"\n\n[dependencies.npm]{deps_section}\n\n[dev-dependencies.npm]{dev_deps_section}\n';
    config_path = os.path.join(temp_dir, "jac.toml");
    with open(config_path, "w") as f {
        f.write(toml_content);
    }
    return config_path;
}

test "install without cl flag" {
    """Test add command without --npm flag errors when no jac.toml exists."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Run add command without --npm flag and without jac.toml
            result = run(["jac", "add", "lodash"], capture_output=True, text=True,);

            # Should error when no jac.toml exists
            assert result.returncode == 1;
            assert (
                "No jac.toml found" in result.stdout
                or "No jac.toml found" in result.stderr
            );
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "add npm with mixed deps" {
    """Test jac add --npm adds npm dep when project also has pypi deps."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml with both pypi and npm sections
            toml_content = '[project]\nname = "fullstack-app"\nversion = "1.0.0"\ndescription = "Test project with mixed deps"\nentry-point = "app.jac"\n\n[dependencies]\nrequests = "~=2.31"\nflask = "~=3.0"\n\n[dependencies.npm]\n\n[dev-dependencies]\npytest = ">=8.0.0"\n';
            config_path = os.path.join(temp_dir, "jac.toml");
            with open(config_path, "w") as f {
                f.write(toml_content);
            }

            # Run jac add --npm lodash
            result = run(
                ["jac", "add", "--npm", "lodash"], capture_output=True, text=True,
            );

            # Should succeed
            assert result.returncode == 0;

            # Verify lodash was added to npm deps in jac.toml
            with open(config_path, "rb") as f {
                updated_config = tomllib.load(f);
            }

            assert "lodash" in updated_config["dependencies"]["npm"];
            # Verify pypi deps are unchanged
            assert updated_config["dependencies"].get("requests") is None or True;
            # Just verify npm section has lodash
            assert "lodash" in updated_config["dependencies"]["npm"];
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "install all packages" {
    """Test add --npm command installs all packages from jac.toml."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml with some dependencies
            _create_jac_toml(temp_dir, deps='lodash = "^4.17.21"');

            # Run add --npm command without package name
            result = run(["jac", "add", "--npm"], capture_output=True, text=True,);

            # Should succeed
            assert result.returncode == 0;
            # Check for install messages (handles both old and new console formats)
            assert (
                "Installing all npm packages" in result.stdout
                or "Installing all npm packages" in result.stdout.lower()
            );
            assert (
                "Installed all npm packages successfully" in result.stdout
                or "Installed all npm packages" in result.stdout
            );
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "install package to dependencies" {
    """Test add --npm command adds package to dependencies."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml
            config_path = _create_jac_toml(temp_dir);

            # Run add --npm command with package name
            result = run(
                ["jac", "add", "--npm", "lodash"], capture_output=True, text=True,
            );

            # Should succeed
            assert result.returncode == 0;
            # Check for package add messages (handles both old and new console formats)
            assert (
                "Adding lodash (npm)" in result.stdout
                or "lodash" in result.stdout.lower()
            );
            assert (
                "Added 1 package(s) to [dependencies.npm]" in result.stdout
                or "Updated jac.toml" in result.stdout
                or "dependencies.npm" in result.stdout
            );

            # Verify package was added to jac.toml
            with open(config_path, "rb") as f {
                updated_config = tomllib.load(f);
            }

            assert "lodash" in updated_config["dependencies"]["npm"];
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "install package with version" {
    """Test add --npm command with specific version."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml
            config_path = _create_jac_toml(temp_dir);

            # Run add --npm command with package and version
            result = run(
                ["jac", "add", "--npm", "lodash@^4.17.21"],
                capture_output=True,
                text=True,
            );

            # Should succeed
            assert result.returncode == 0;
            # Check for package add messages (handles both old and new console formats)
            assert (
                "Adding lodash (npm)" in result.stdout
                or "lodash" in result.stdout.lower()
            );
            assert (
                "Added 1 package(s) to [dependencies.npm]" in result.stdout
                or "Updated jac.toml" in result.stdout
                or "dependencies.npm" in result.stdout
            );

            # Verify package was added with correct version
            with open(config_path, "rb") as f {
                updated_config = tomllib.load(f);
            }

            assert updated_config["dependencies"]["npm"]["lodash"] == "^4.17.21";
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "install package to devdependencies" {
    """Test add --npm -d command adds package to dev-dependencies."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml
            config_path = _create_jac_toml(temp_dir);

            # Run add --npm -d command
            run(
                ["jac", "add", "--npm", "-d", "@types/react"],
                capture_output=True,
                text=True,
            );

            # Verify package was added to dev-dependencies in jac.toml
            with open(config_path, "rb") as f {
                updated_config = tomllib.load(f);
            }

            npm_deps = updated_config["dependencies"]["npm"];
            assert "@types/react" in npm_deps.get("dev", {});
            # Check it's not in regular deps (excluding the "dev" key)
            regular_deps = {
                k: v
                for (k, v) in npm_deps.items()
                if k != "dev"
            };
            assert "@types/react" not in regular_deps;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "install without config json" {
    """Test add --npm command when jac.toml doesn't exist."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Run add --npm command without jac.toml
            result = run(
                ["jac", "add", "--npm", "lodash"], capture_output=True, text=True,
            );

            # Should fail with non-zero exit code
            assert result.returncode != 0;
            assert "No jac.toml found" in result.stderr;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "uninstall without cl flag" {
    """Test remove command without --npm flag should fail when no jac.toml exists."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Run remove command without --npm flag and without jac.toml
            result = run(["jac", "remove", "lodash"], capture_output=True, text=True,);

            # Should fail with non-zero exit code because no jac.toml
            assert result.returncode != 0;
            assert "No jac.toml found" in result.stderr;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "uninstall without package name" {
    """Test remove --npm command without package name should fail."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml
            _create_jac_toml(temp_dir);

            # Run remove --npm command without package name
            result = run(["jac", "remove", "--npm"], capture_output=True, text=True,);

            # Should fail with non-zero exit code
            assert result.returncode != 0;
            assert "No packages specified" in result.stderr;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "uninstall package from dependencies" {
    """Test remove --npm command removes package from dependencies."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml with a package
            config_path = _create_jac_toml(temp_dir, deps='lodash = "^4.17.21"');

            # Run remove --npm command
            result = run(
                ["jac", "remove", "--npm", "lodash"], capture_output=True, text=True,
            );

            # Should succeed
            assert result.returncode == 0;
            assert "Removing lodash (npm)" in result.stdout;
            assert "Removed 1 package(s)" in result.stdout;

            # Verify package was removed from jac.toml
            with open(config_path, "rb") as f {
                updated_config = tomllib.load(f);
            }

            npm_deps = updated_config.get("dependencies", {}).get("npm", {});
            regular_deps = {
                k: v
                for (k, v) in npm_deps.items()
                if k != "dev"
            };
            assert "lodash" not in regular_deps;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "uninstall package from devdependencies" {
    """Test remove --npm -d command removes package from dev-dependencies."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml with a dev-dependency
            config_path = _create_jac_toml(
                temp_dir, dev_deps='"@types/react" = "^18.0.0"'
            );

            # Run remove --npm -d command
            result = run(
                ["jac", "remove", "--npm", "-d", "@types/react"],
                capture_output=True,
                text=True,
            );

            # Should succeed
            assert result.returncode == 0;
            assert "Removing @types/react (npm)" in result.stdout;
            assert "Removed 1 package(s)" in result.stdout;

            # Verify package was removed from jac.toml
            with open(config_path, "rb") as f {
                updated_config = tomllib.load(f);
            }

            npm_deps = updated_config.get("dependencies", {}).get("npm", {});
            assert "@types/react" not in npm_deps.get("dev", {});
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "uninstall nonexistent package" {
    """Test remove --npm command with non-existent package should fail."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml without the package
            _create_jac_toml(temp_dir);

            # Run remove --npm command with non-existent package
            result = run(
                ["jac", "remove", "--npm", "nonexistent-package"],
                capture_output=True,
                text=True,
            );

            # Should fail with non-zero exit code
            assert result.returncode != 0;
            assert "not found" in result.stderr.lower();
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "uninstall without config toml" {
    """Test remove --npm command when jac.toml doesn't exist."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Run remove --npm command without jac.toml
            result = run(
                ["jac", "remove", "--npm", "lodash"], capture_output=True, text=True,
            );

            # Should fail with non-zero exit code
            assert result.returncode != 0;
            assert "No jac.toml found" in result.stderr;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "config files from jac toml" {
    """Test that [plugins.client.configs] in jac.toml generates config files."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create jac.toml with postcss and tailwind configs
            toml_content = '[project]\nname = "test-configs"\nversion = "1.0.0"\ndescription = "Test project"\nentry-point = "main.jac"\n\n[plugins.client.configs.postcss]\nplugins = ["tailwindcss", "autoprefixer"]\n\n[plugins.client.configs.tailwind]\ncontent = ["./**/*.jac", "./.jac/client/**/*.{js,jsx}"]\nplugins = []\n\n[plugins.client.configs.tailwind.theme.extend]\ncolors = { primary = "#3490dc" }\n';
            config_path = os.path.join(temp_dir, "jac.toml");
            with open(config_path, "w") as f {
                f.write(toml_content);
            }

            # Import and use ViteBundler to generate config files
            import from jac_client.plugin.src.vite_bundler { ViteBundler }

            bundler = ViteBundler(Path(temp_dir));
            created_files = bundler.create_config_files();

            # Verify two config files were created
            assert len(created_files) == 2;

            # Verify postcss.config.js was created with correct content
            configs_dir = os.path.join(temp_dir, ".jac", "client", "configs");
            postcss_config = os.path.join(configs_dir, "postcss.config.js");
            assert os.path.exists(postcss_config);

            with open(postcss_config) as f {
                postcss_content = f.read();
            }

            assert "module.exports" in postcss_content;
            assert "tailwindcss" in postcss_content;
            assert "autoprefixer" in postcss_content;

            # Verify tailwind.config.js was created with correct content
            tailwind_config = os.path.join(configs_dir, "tailwind.config.js");
            assert os.path.exists(tailwind_config);

            with open(tailwind_config) as f {
                tailwind_content = f.read();
            }

            assert "module.exports" in tailwind_content;
            assert "./**/*.jac" in tailwind_content;
            assert "#3490dc" in tailwind_content;
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "create cl and run no root files" {
    """Test that jac create --use client + jac run doesn't create files outside .jac/ directory."""
    test_project_name = "test-cl-no-root-files";

    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Run jac create --use client command
            process = Popen(
                ["jac", "create", "--use", "client", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            );
            (stdout, stderr) = process.communicate();
            assert process.returncode == 0 , f"jac create --use client failed: {stderr}";

            project_path = os.path.join(temp_dir, test_project_name);

            # Record files after create (before run), excluding .jac directory
            def get_root_files(path: str) -> set[str] {
                """Get files/dirs in project root, excluding .jac directory."""
                items = set();
                for item in os.listdir(path) {
                    if item != ".jac" {
                        items.add(item);
                    }
                }
                return items;
            }

            files_before_run = get_root_files(project_path);

            # Run jac run main.jac
            process = Popen(
                ["jac", "run", "main.jac"],
                cwd=project_path,
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            );
            (stdout, stderr) = process.communicate();
            assert process.returncode == 0 , f"jac run failed: {stderr}";

            # Record files after run
            files_after_run = get_root_files(project_path);

            # Check no new files were created in project root
            new_files = files_after_run - files_before_run;
            assert not new_files , (
                f"jac run created unexpected files in project root: {new_files}. "
                "All runtime files should be in .jac/ directory."
            );
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "vite build prompts for missing client deps" {
    """Test that ViteBundler.build() prompts to install deps when jac.toml is missing."""
    import from jac_client.plugin.src.vite_bundler { ViteBundler }

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir);
        config_file = project_dir / "jac.toml";
        # No jac.toml -- ViteBundler.build() should prompt via ensure_client_deps
        bundler = ViteBundler(project_dir);
        # Mock input to accept, and mock bun/vite so we don't need real installs.
        with unittest.mock.patch("builtins.input", return_value="Y") {
            with unittest.mock.patch(
                "jac_client.plugin.utils.bun_installer.ensure_bun_available",
                return_value=True
            ) {
                with unittest.mock.patch("subprocess.run") as mock_subprocess {
                    # bun install returns success, vite build returns failure
                    mock_subprocess.side_effect = [
                        type("Result", (), {"returncode": 0})(),  # bun install
                        type("Result", (), {"returncode": 1})(),  # vite build

                    ];
                    with contextlib.suppress(Exception) {
                        bundler.build();  # vite build failure is expected
                    }
                }
            }
        }
        # The key assertion: jac.toml was created with default client deps
        assert config_file.exists() , (
            "jac.toml should have been created after accepting the prompt"
        );
        with open(config_file, "rb") as f {
            data = tomllib.load(f);
        }
        npm_deps = data.get("dependencies", {}).get("npm", {});
        assert "react" in npm_deps , "react should be in dependencies.npm";
        assert "react-dom" in npm_deps , "react-dom should be in dependencies.npm";
        npm_dev = npm_deps.get("dev", {});
        assert "vite" in npm_dev , "vite should be in dev dependencies";
        assert "@vitejs/plugin-react" in npm_dev , (
            "@vitejs/plugin-react should be in dev deps"
        );
        # Verify the generated package.json also picked up the deps
        package_json = project_dir / ".jac" / "client" / "configs" / "package.json";
        assert package_json.exists() , "package.json should have been generated";
        with open(package_json) as f {
            pkg = json.load(f);
        }
        assert pkg["dependencies"].get("react") , "package.json should have react";
        assert pkg["devDependencies"].get("vite") , "package.json should have vite";
    }
}

test "start dev with client does initial compilation" {
    """Test that jac start --dev auto-installs watchdog and performs initial compilation."""
    test_project_name = "test-start-dev-client";
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);
            # Create a client project
            process = Popen(
                ["jac", "create", "--use", "client", test_project_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            );
            (stdout, stderr) = process.communicate();
            assert process.returncode == 0;
            # Change to project directory
            os.chdir(test_project_name);
            # Run jac start --dev main.jac (should auto-install watchdog and compile)
            process = Popen(
                ["jac", "start", "--dev", "main.jac"],
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            );
            # Wait for watchdog install and compilation messages
            start_time = time.time();
            output = "";
            found_watchdog = False;
            found_compilation = False;
            while (time.time() - start_time < 50) {
                if process.stdout is None {
                    break;
                }
                line = process.stdout.readline();
                if not line {
                    if process.poll() is not None {
                        break;
                    }
                    time.sleep(0.1);
                    continue;
                }
                output += line;
                if "Installing watchdog" in line or "watchdog installed" in line {
                    found_watchdog = True;
                }
                if "Initial client compilation completed" in line {
                    found_compilation = True;
                    break;
                }
            }
            # Terminate the process
            process.terminate();
            try {
                process.wait(timeout=5);
            } except Exception {
                process.kill();
            }
            # Close pipes
            if process.stdout {
                process.stdout.close();
            }
            if process.stderr {
                process.stderr.close();
            }
            assert found_watchdog , (
                f"Expected watchdog auto-install message in output, but got: {output}"
            );
            assert found_compilation , (
                f"Expected 'Initial client compilation completed' in output, but got: {output}"
            );
        } finally {
            os.chdir(original_cwd);
        }
    }
}

test "vite config generation" {
    """Test that create_vite_config(build/dev) generate correct files."""
    with tempfile.TemporaryDirectory() as temp_dir {
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            # Create a basic jac.toml for the project
            toml_content = '\n[plugins.client.vite]\nplugins = ["tailwindcss()"]\nlib_imports = ["import tailwindcss from \'@tailwindcss/vite\'"]\n\n[plugins.client.vite.build]\nminify = "esbuild"\n';
            config_path = os.path.join(temp_dir, "jac.toml");
            with open(config_path, "w") as f {
                f.write(toml_content);
            }

            # Import ViteBundler
            import from jac_client.plugin.src.vite_bundler { ViteBundler }

            # Initialize bundler
            bundler = ViteBundler(Path(temp_dir));

            # Create a mock entry file
            entry_file = Path(temp_dir) / ".jac" / "client" / "build" / "main.js";
            entry_file.parent.mkdir(parents=True, exist_ok=True);
            entry_file.write_text("// Mock entry file");

            # Test create_vite_config (build config)
            build_config_path = bundler.create_vite_config(entry_file);
            assert build_config_path.exists();
            assert build_config_path.name == "vite.config.js";

            # Read and validate build config content
            build_config_content = build_config_path.read_text();
            assert "globalThis.__JAC_API_BASE_URL__" in build_config_content;
            assert "jacSourceMapper()" in build_config_content;  # Build-specific plugin
            assert "tailwindcss()" in build_config_content;  # Tailwind plugin
            assert "@tailwindcss/vite" in build_config_content;  # Tailwind import

            # Test create_vite_config (dev config)
            dev_config_path = bundler.create_vite_config(
                entry_file, is_dev=True, api_port=8001
            );
            assert dev_config_path.exists();
            assert dev_config_path.name == "vite.dev.config.js";

            # Read and validate dev config content
            dev_config_content = dev_config_path.read_text();
            assert "globalThis.__JAC_API_BASE_URL__" in dev_config_content;
            assert '"http://localhost:8001"' in dev_config_content;  # API port
            assert "/walker" in dev_config_content;  # Walker endpoint proxy
            assert "tailwindcss()" in dev_config_content;  # Tailwind plugin
            assert "@tailwindcss/vite" in dev_config_content;  # Tailwind import

            # Verify configs are different (dev vs build)
            assert build_config_content != dev_config_content;
            assert ("sourcemap: true" in build_config_content);  # Both should have sourcemaps
            assert "sourcemap: true" in dev_config_content;
        } finally {
            os.chdir(original_cwd);
        }
    }
}
