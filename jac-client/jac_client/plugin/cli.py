"""Command line interface tool for the Jac Client."""

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from jaclang.cli.cmdreg import cmd_registry
from jaclang.pycore.runtime import hookimpl


class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Create Jac CLI cmds."""

        @cmd_registry.register
        def create_jac_app(name: str) -> None:
            """Create a new Jac application with npm and Vite setup.

            Bootstraps a new Jac project by creating a temporary directory, initializing
            npm, installing Vite, and setting up the basic project structure.

            Args:
                name: Name of the project to create

            Examples:
                jac create_jac_app my-app
                jac create_jac_app my-jac-project
            """
            if not name:
                print(
                    "Error: Project name is required. Use --name=your-project-name",
                    file=sys.stderr,
                )
                exit(1)

            # Validate project name (basic npm package name validation)
            if not re.match(r"^[a-zA-Z0-9_-]+$", name):
                print(
                    "Error: Project name must contain only letters, numbers, hyphens, and underscores",
                    file=sys.stderr,
                )
                exit(1)

            print(f"Creating new Jac application: {name}")

            # Ask if TypeScript support is needed
            use_typescript = False
            while True:
                ts_input = (
                    input("Does your project require TypeScript support? (y/n): ")
                    .strip()
                    .lower()
                )
                if ts_input in ("y", "yes"):
                    use_typescript = True
                    break
                elif ts_input in ("n", "no"):
                    use_typescript = False
                    break
                else:
                    print("Please enter 'y' for yes or 'n' for no.")

            # Create project directory in current working directory
            project_path = os.path.join(os.getcwd(), name)

            if os.path.exists(project_path):
                print(
                    f"Error: Directory '{name}' already exists in current location",
                    file=sys.stderr,
                )
                exit(1)

            os.makedirs(project_path, exist_ok=True)

            try:
                # Change to project directory
                original_cwd = os.getcwd()
                os.chdir(project_path)

                # create compiled folder for transpiled files
                compiled_folder = os.path.join(project_path, "compiled")
                os.makedirs(compiled_folder, exist_ok=True)

                # create build folder
                build_folder = os.path.join(project_path, "build")
                os.makedirs(build_folder, exist_ok=True)

                # create assets folder for static assets (images, fonts, etc.)
                assets_folder = os.path.join(project_path, "assets")
                os.makedirs(assets_folder, exist_ok=True)

                # Create config.json with package configuration
                # Default dependencies and scripts are added during build time, not in config.json
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
                        "name": name,
                        "version": "1.0.0",
                        "description": f"Jac application: {name}",
                        "devDependencies": {},
                        "dependencies": {},
                    },
                }

                # Write config.json
                config_file_path = os.path.join(project_path, "config.json")
                with open(config_file_path, "w") as f:
                    json.dump(config_data, f, indent=2)

                print("✅ Created config.json with package configuration")
                print(
                    "📦 package.json will be generated in .jac-client.configs/ on first build"
                )

                # Create basic project structure
                print("Setting up project structure...")

                # Prepare app.jac content based on TypeScript choice
                if use_typescript:
                    main_jac_content = """
# Pages
cl import from react {useState, useEffect}
cl import from ".components/Button.tsx" { Button }

cl {
    def app() -> any {
        [count, setCount] = useState(0);
        useEffect(lambda -> None {
            console.log("Count: ", count);
        }, [count]);
        return <div style={{padding: "2rem", fontFamily: "Arial, sans-serif"}}>
            <h1>Hello, World!</h1>
            <p>Count: {count}</p>
            <div style={{display: "flex", gap: "1rem", marginTop: "1rem"}}>
                <Button
                    label="Increment"
                    onClick={lambda -> None {setCount(count + 1);}}
                    variant="primary"
                />
                <Button
                    label="Reset"
                    onClick={lambda -> None {setCount(0);}}
                    variant="secondary"
                />
            </div>
        </div>;
    }
}
"""
                else:
                    main_jac_content = """
# Pages
cl import from react {useState, useEffect}
cl {
    def app() -> any {
        [count, setCount] = useState(0);
        useEffect(lambda -> None {
            console.log("Count: ", count);
        }, [count]);
        return <div>
            <h1>Hello, World!</h1>
            <p>Count: {count}</p>
            <button onClick={lambda e: any ->  None {setCount(count + 1);}}>Increment</button>
        </div>;
    }
}
"""

                # Create app.jac file
                with open(os.path.join(project_path, "app.jac"), "w") as f:
                    f.write(main_jac_content)

                # Note: vite.config.js will be generated automatically in .jac-client.configs/
                # during the first bundling process (when running jac serve)

                # Create TypeScript configuration if requested
                if use_typescript:
                    tsconfig_content = """{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,

    /* Bundler mode */
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",

    /* Linting */
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["components/**/*"],
  "exclude": ["node_modules", "dist", "build", "compiled"]
}
"""
                    with open(os.path.join(project_path, "tsconfig.json"), "w") as f:
                        f.write(tsconfig_content)

                    # Create components directory with a sample TypeScript component
                    components_dir = os.path.join(project_path, "components")
                    os.makedirs(components_dir, exist_ok=True)

                    button_component_content = """import React from 'react';

interface ButtonProps {
  label: string;
  onClick?: () => void;
  variant?: 'primary' | 'secondary';
  disabled?: boolean;
}

export const Button: React.FC<ButtonProps> = ({
  label,
  onClick,
  variant = 'primary',
  disabled = false
}) => {
  const baseStyles: React.CSSProperties = {
    padding: '0.75rem 1.5rem',
    fontSize: '1rem',
    fontWeight: '600',
    borderRadius: '0.5rem',
    border: 'none',
    cursor: disabled ? 'not-allowed' : 'pointer',
    transition: 'all 0.2s ease',
  };

  const variantStyles: Record<string, React.CSSProperties> = {
    primary: {
      backgroundColor: disabled ? '#9ca3af' : '#3b82f6',
      color: '#ffffff',
    },
    secondary: {
      backgroundColor: disabled ? '#e5e7eb' : '#6b7280',
      color: '#ffffff',
    },
  };

  return (
    <button
      style={{ ...baseStyles, ...variantStyles[variant] }}
      onClick={onClick}
      disabled={disabled}
    >
      {label}
    </button>
  );
};

export default Button;
"""
                    with open(os.path.join(components_dir, "Button.tsx"), "w") as f:
                        f.write(button_component_content)

                # Create README.md
                if use_typescript:
                    readme_content = f"""# {name}

## Running Jac Code

Make sure node modules are installed:
```bash
npm install
```

To run your Jac code, use the Jac CLI:

```bash
jac serve app.jac
```

## TypeScript Support

This project includes TypeScript support. You can create TypeScript components in the `components/` directory and import them in your Jac files.

Example:
```jac
cl import from ".components/Button.tsx" {{ Button }}
```

See `components/Button.tsx` for an example TypeScript component.

For more information, see the [TypeScript guide](../../docs/working-with-ts.md).

Happy coding with Jac and TypeScript! 🚀
"""
                else:
                    readme_content = f"""# {name}

## Running Jac Code

Make sure node modules are installed:
```bash
npm install
```

To run your Jac code, use the Jac CLI:

```bash
jac serve app.jac
```

Happy coding with Jac!
"""

                with open(os.path.join(project_path, "README.md"), "w") as f:
                    f.write(readme_content)

                # Create .gitignore file
                gitignore_content = """node_modules
app.session.bak
app.session.dat
app.session.dir
app.session.users.json
compiled/
.jac-client.configs/
"""
                with open(os.path.join(project_path, ".gitignore"), "w") as f:
                    f.write(gitignore_content)

                # Return to original directory
                os.chdir(original_cwd)

                print(f"✅ Successfully created Jac application '{name}'!")
                print(f"📁 Project location: {os.path.abspath(project_path)}")
                print("\nNext steps:")
                print(f"  cd {name}")
                print("  jac serve app.jac")

            except subprocess.CalledProcessError as e:
                # Return to original directory on error
                os.chdir(original_cwd)
                print(f"Error running npm command: {e}", file=sys.stderr)
                print(f"Command output: {e.stdout}", file=sys.stderr)
                print(f"Command error: {e.stderr}", file=sys.stderr)
                exit(1)
            except Exception as e:
                # Return to original directory on error
                os.chdir(original_cwd)
                print(f"Error creating project: {e}", file=sys.stderr)
                exit(1)

        @cmd_registry.register
        def generate_client_config() -> None:
            """Generate config.json file for customizing Jac Client build configuration.

            Creates a config.json file in the current directory with default structure
            that can be customized for plugins, build options, and other settings.

            Examples:
                jac generate_client_config
            """
            current_dir = Path(os.getcwd())
            config_file = current_dir / "config.json"

            if config_file.exists():
                print(
                    f"⚠️  config.json already exists at {config_file}",
                    file=sys.stderr,
                )
                print(
                    "If you want to regenerate it, delete the existing file first.",
                    file=sys.stderr,
                )
                exit(1)

            try:
                # Get default configuration structure
                default_config: dict[str, Any] = {
                    "vite": {
                        "plugins": [],
                        "lib_imports": [],
                        "build": {},
                        "server": {},
                        "resolve": {},
                    },
                    "ts": {},
                    "package": {
                        "name": "",
                        "version": "1.0.0",
                        "description": "",
                        "dependencies": {},
                        "devDependencies": {},
                    },
                }

                # Write config.json
                with config_file.open("w", encoding="utf-8") as f:
                    json.dump(default_config, f, indent=2)

                print(f"✅ Successfully created config.json at {config_file}")
                print("\nYou can now customize:")
                print("  - vite.plugins: Add Vite plugins (e.g., ['tailwindcss()'])")
                print("  - vite.lib_imports: Add import statements")
                print("  - vite.build: Override build options")
                print("  - vite.server: Configure dev server")
                print("  - vite.resolve: Override resolve options")
                print("  - package.dependencies: Add npm dependencies")
                print("  - package.devDependencies: Add npm dev dependencies")
                print("  - package.scripts: Customize npm scripts")
                print("\nExample for Tailwind CSS:")
                print('  "vite": {')
                print('    "plugins": ["tailwindcss()"],')
                print(
                    '    "lib_imports": ["import tailwindcss from \'@tailwindcss/vite\'"]'
                )
                print("  },")
                print('  "package": {')
                print('    "devDependencies": {')
                print('      "@tailwindcss/vite": "^4.1.17"')
                print("    }")
                print("  }")
                print(
                    "\nNote: package.json will be generated in .jac-client.configs/ on build"
                )

            except Exception as e:
                print(f"Error creating config.json: {e}", file=sys.stderr)
                exit(1)

        @cmd_registry.register
        def add(filepath: str = "", cl: bool = False, d: bool = False) -> None:
            """Add npm packages to Jac Client projects.

            Adds packages to config.json (dependencies or devDependencies).
            The --cl flag indicates this is for client-side packages.
            Use -D flag to add to devDependencies instead of dependencies.

            Args:
                filepath: Package name to add (e.g., "lodash" or "lodash@^4.17.21")
                cl: Flag to indicate client-side package installation
                d: Flag to add to devDependencies (default: dependencies)

            Examples:
                jac add --cl                    # Install all packages from config.json
                jac add --cl lodash             # Add specific package
                jac add --cl -d @types/react    # Add as devDependency
                jac add --cl lodash@^4.17.21    # Add with specific version
            """
            # Note: cl should be detected as boolean, but if not, we check it here
            if not cl:
                print(
                    "Error: --cl flag is required for client package installation",
                    file=sys.stderr,
                )
                print(
                    "Usage: jac add --cl <package_name>",
                    file=sys.stderr,
                )
                print(
                    "       jac add --cl -d <package_name>  (for devDependencies)",
                    file=sys.stderr,
                )
                exit(1)

            try:
                from pathlib import Path

                from jac_client.plugin.src.package_installer import PackageInstaller

                current_dir = Path(os.getcwd())
                installer = PackageInstaller(current_dir)

                # If no package name provided, install all packages from config.json
                if not filepath:
                    print("📦 Installing all packages from config.json...")
                    installer.install_all()
                    print("✅ Successfully installed all packages")
                    return

                # Parse package name and version
                # Handle scoped packages (e.g., @types/react)
                # Version separator is @, but @ at start is part of package name
                if filepath.startswith("@"):
                    # For scoped packages, find version separator after the scope
                    # e.g., @types/react@^18.0.0 -> @types/react, ^18.0.0
                    last_at_index = filepath.rfind("@")
                    if last_at_index > 0:  # @ found and not at position 0
                        package_name = filepath[:last_at_index]
                        package_version = filepath[last_at_index + 1 :]
                    else:
                        package_name = filepath
                        package_version = None
                else:
                    # For non-scoped packages, split on first @
                    package_parts = filepath.split("@", 1)
                    package_name = package_parts[0]
                    package_version = (
                        package_parts[1] if len(package_parts) > 1 else None
                    )

                # Install the package
                installer.install_package(
                    package_name=package_name, version=package_version, is_dev=d
                )

                dep_type = "devDependencies" if d else "dependencies"
                version_str = f"@{package_version}" if package_version else ""
                print(
                    f"✅ Added {package_name}{version_str} to {dep_type} in config.json"
                )
                print("📦 Installing package via npm...")
                # npm install is handled by PackageInstaller.install_package()
                print(f"✅ Successfully installed {package_name}{version_str}")

            except Exception as e:
                print(f"Error adding package: {e}", file=sys.stderr)
                exit(1)

        @cmd_registry.register
        def remove(filepath: str, cl: bool = False, d: bool = False) -> None:
            """Remove npm packages from Jac Client projects.

            Removes packages from config.json (dependencies or devDependencies).
            The --cl flag indicates this is for client-side packages.
            Use -D flag to remove from devDependencies instead of dependencies.

            Args:
                filepath: Package name to remove (required)
                cl: Flag to indicate client-side package removal
                d: Flag to remove from devDependencies (default: dependencies)

            Examples:
                jac remove --cl lodash             # Remove from dependencies
                jac remove --cl -D @types/react    # Remove from devDependencies
            """
            if not cl:
                print(
                    "Error: --cl flag is required for client package removal",
                    file=sys.stderr,
                )
                print(
                    "Usage: jac remove --cl <package_name>",
                    file=sys.stderr,
                )
                print(
                    "       jac remove --cl -D <package_name>  (for devDependencies)",
                    file=sys.stderr,
                )
                exit(1)

            if not filepath:
                print(
                    "Error: Package name is required",
                    file=sys.stderr,
                )
                print(
                    "Usage: jac remove --cl <package_name>",
                    file=sys.stderr,
                )
                exit(1)

            try:
                from pathlib import Path

                from jac_client.plugin.src.package_installer import PackageInstaller

                current_dir = Path(os.getcwd())
                installer = PackageInstaller(current_dir)

                # Uninstall the package
                installer.uninstall_package(package_name=filepath, is_dev=d)

                dep_type = "devDependencies" if d else "dependencies"
                print(f"✅ Removed {filepath} from {dep_type} in config.json")
                print("📦 Updating packages via npm...")
                # npm install is handled by PackageInstaller.uninstall_package()
                print(f"✅ Successfully removed {filepath}")

            except Exception as e:
                print(f"Error removing package: {e}", file=sys.stderr)
                exit(1)
