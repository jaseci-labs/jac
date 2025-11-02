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
                temp_folder = os.path.join(project_path, "temp")
                os.makedirs(temp_folder, exist_ok=True)

                # create static/client/js folder
                client_js_folder = os.path.join(project_path, "static", "client", "js")
                os.makedirs(client_js_folder, exist_ok=True)

                # Update package.json with Jac-specific configuration
                package_data.update(
                    {
                        "name": name,
                        "description": f"Jac application: {name}",
                        "type": "module",
                        "scripts": {
                            "build": "vite build",
                            "dev": "vite dev",
                            "preview": "vite preview",
                        },
                        "devDependencies": {"vite": "^5.0.0"},
                        "dependencies": {"react": "^18.2.0", "react-dom": "^18.2.0"},
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
cl def HomeView() -> any {
    return <div
    style={{
        "minHeight": "100vh",
        "fontFamily": "-apple-system, BlinkMacSystemFont, sans-serif"
    }}>
        <main
        style={{
            "maxWidth": "1200px",
            "margin": "0 auto",
            "padding": "60px 40px"
        }}>
            <div
            style={{
                "textAlign": "center",
                "marginBottom": "80px"
            }}>
                <h1
                style={{
                    "fontSize": "56px",
                    "marginBottom": "20px"
                }}>
                    Welcome to
                    <span style={{"color": "#007bff"}}>OneLang</span>
                </h1>
                <p
                style={{
                    "fontSize": "20px",
                    "color": "#666"
                }}>
                    One Language. One Stack. Zero Friction.
                </p>
            </div>

            <div
            style={{
                "display": "grid",
                "gridTemplateColumns": "repeat(2, 1fr)",
                "gap": "24px",
                "marginBottom": "60px"
            }}>
                <a
                href="https://docs.jaseci.org"
                target="_blank"
                style={{
                    "padding": "32px",
                    "backgroundColor": "white",
                    "border": "1px solid #eaeaea",
                    "borderRadius": "8px",
                    "textDecoration": "none",
                    "color": "#000"
                }}>
                    <h3
                    style={{
                        "marginTop": "0",
                        "marginBottom": "12px"
                    }}>📖 Documentation</h3>
                    <p style={{"color": "#666", "margin": "0"}}>
                        Learn how to build with OneLang
                    </p>
                </a>
                <a
                href="https://docs.jaseci.org/learn"
                target="_blank"
                style={{
                    "padding": "32px",
                    "backgroundColor": "white",
                    "border": "1px solid #eaeaea",
                    "borderRadius": "8px",
                    "textDecoration": "none",
                    "color": "#000"
                }}>
                    <h3
                    style={{
                        "marginTop": "0",
                        "marginBottom": "12px"
                    }}>🎓 Learn</h3>
                    <p style={{"color": "#666", "margin": "0"}}>
                        Tutorials and guides
                    </p>
                </a>
                <a
                href="/examples"
                style={{
                    "padding": "32px",
                    "backgroundColor": "white",
                    "border": "1px solid #eaeaea",
                    "borderRadius": "8px",
                    "textDecoration": "none",
                    "color": "#000"
                }}>
                    <h3
                    style={{
                        "marginTop": "0",
                        "marginBottom": "12px"
                    }}>💡 Examples</h3>
                    <p style={{"color": "#666", "margin": "0"}}>
                        Sample applications
                    </p>
                </a>
                <a
                href="https://github.com/Jaseci-Labs/jaseci"
                target="_blank"
                style={{
                    "padding": "32px",
                    "backgroundColor": "white",
                    "border": "1px solid #eaeaea",
                    "borderRadius": "8px",
                    "textDecoration": "none",
                    "color": "#000"
                }}>
                    <h3
                    style={{
                        "marginTop": "0",
                        "marginBottom": "12px"
                    }}>🔧 Community</h3>
                    <p style={{"color": "#666", "margin": "0"}}>
                        GitHub repository
                    </p>
                </a>
            </div>

            <footer
            style={{
                "borderTop": "1px solid #eaeaea",
                "paddingTop": "40px",
                "textAlign": "center",
                "color": "#999"
            }}>
                <p>
                    Get started by editing
                    <code
                    style={{
                        "backgroundColor": "#f5f5f5",
                        "padding": "2px 6px",
                        "borderRadius": "3px"
                    }}>app.jac</code>
                </p>
            </footer>
        </main>
    </div>;
}


# Main App component with declarative router
cl def App() -> any {

    home_route = {
        "path": "/",
        "component": lambda -> any { return HomeView(); },
        "guard": None
    };

    routes = [home_route];
    router = initRouter(routes, "/");

    # add all the wrapper components here
    return <div class="app-container">
        {router.render()}
    </div>;
}

# Main SPA entry point - simplified with reactive routing
cl def jac_app() -> any {
    return App();
}
"""

                with open(os.path.join(project_path, "app.jac"), "w") as f:
                    f.write(main_jac_content)

                # Create README.md
                readme_content = f"""# {name}

                ## Running Jac Code

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
