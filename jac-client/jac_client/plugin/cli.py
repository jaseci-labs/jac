"""Command line interface tool for the Jac Client."""

import json
import os
import re
import subprocess
import sys

from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.machine import hookimpl


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

                # Initialize npm package
                print("Initializing npm package...")
                npm_init_cmd = ["npm", "init", "-y"]
                subprocess.run(npm_init_cmd, capture_output=True, text=True, check=True)

                # Read the generated package.json
                package_json_path = os.path.join(project_path, "package.json")
                with open(package_json_path, "r") as f:
                    package_data = json.load(f)

                # create temp folder
                src_folder = os.path.join(project_path, "src")
                os.makedirs(src_folder, exist_ok=True)

                # create build folder
                build_folder = os.path.join(project_path, "build")
                os.makedirs(build_folder, exist_ok=True)

                # create assets folder for static assets (images, fonts, etc.)
                assets_folder = os.path.join(project_path, "assets")
                os.makedirs(assets_folder, exist_ok=True)

                # Update package.json with Jac-specific configuration
                package_data.update(
                    {
                        "name": name,
                        "description": f"Jac application: {name}",
                        "type": "module",
                        "scripts": {
                            "build": "npm run compile && vite build",
                            "dev": "vite dev",
                            "preview": "vite preview",
                            "compile": 'babel src --out-dir build --extensions ".jsx,.js" --out-file-extension .js',
                        },
                        "devDependencies": {
                            "vite": "^6.4.1",
                            "@babel/cli": "^7.28.3",
                            "@babel/core": "^7.28.5",
                            "@babel/preset-env": "^7.28.5",
                            "@babel/preset-react": "^7.28.5",
                        },
                        "dependencies": {
                            "react": "^19.2.0",
                            "react-dom": "^19.2.0",
                            "react-router-dom": "^6.30.1",
                        },
                    }
                )

                # Write updated package.json
                with open(package_json_path, "w") as f:
                    json.dump(package_data, f, indent=2)

                print("Installing Vite...")
                # Install Vite
                npm_install_cmd = ["npm", "install"]
                subprocess.run(
                    npm_install_cmd, capture_output=True, text=True, check=True
                )

                # Create basic project structure
                print("Setting up project structure...")

                # Create a basic Jac file
                main_jac_content = """
# Pages
cl import from react {useState, useEffect}
cl {
    def app() -> any {
        let [count, setCount] = useState(0);
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

                with open(os.path.join(project_path, "app.jac"), "w") as f:
                    f.write(main_jac_content)

                # create .babelrc file
                babel_config_content = """
{
    "presets": [[
        "@babel/preset-env",
        {
            "modules": false
        }
    ], "@babel/preset-react"]
}
"""
                with open(os.path.join(project_path, ".babelrc"), "w") as f:
                    f.write(babel_config_content)

                # create vite.config.js file
                vite_config_content = """
import { defineConfig } from "vite";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  root: ".", // base folder
  build: {
    rollupOptions: {
      input: "build/main.js", // your compiled entry file
      output: {
        entryFileNames: "client.[hash].js", // name of the final js file
        assetFileNames: "[name].[ext]",
      },
    },
    outDir: "dist", // final bundled output
    emptyOutDir: true,
  },
  publicDir: false,
  resolve: {
    alias: {
      "@jac-client/utils": path.resolve(__dirname, "src/client_runtime.js"),
      "@jac-client/assets": path.resolve(__dirname, "src/assets"),
    },
  },
});

"""
                with open(os.path.join(project_path, "vite.config.js"), "w") as f:
                    f.write(vite_config_content)

                # Create README.md
                readme_content = f"""# {name}

## Running Jac Code

make sure node modules are installed:
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
