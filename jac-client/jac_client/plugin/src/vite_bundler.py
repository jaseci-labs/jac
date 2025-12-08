"""Vite bundling module."""

from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

from jaclang.runtimelib.client_bundle import ClientBundleError

from .config_loader import JacClientConfig


class ViteBundler:
    """Handles Vite bundling operations."""

    def __init__(
        self,
        project_dir: Path,
        output_dir: Path | None = None,
        minify: bool = False,
        config_path: Path | None = None,
    ):
        """Initialize the Vite bundler.

        Args:
            project_dir: Path to the project directory containing package.json
            output_dir: Output directory for Vite builds (defaults to compiled/dist/assets)
            minify: Whether to enable minification in Vite build
            config_path: Optional custom path to vite.config.js (if None, uses default)
        """
        self.project_dir = project_dir
        self.output_dir = output_dir or (project_dir / "compiled" / "dist" / "assets")
        self.minify = minify
        self.config_path = config_path
        self.config_loader = JacClientConfig(project_dir)

    def build(self, entry_file: Path | None = None) -> None:
        """Run Vite build with generated config in .jac-client.configs/.

        Args:
            entry_file: Path to the entry file (build/main.js). If None and config_path
                is not set, will try to use npm run build.

        Raises:
            ClientBundleError: If Vite build fails
        """
        self.output_dir.mkdir(parents=True, exist_ok=True)

        try:
            if self.config_path:
                # Use provided custom config path
                command = ["npx", "vite", "build", "--config", str(self.config_path)]
            elif entry_file:
                # Generate config in .jac-client.configs/ and use it
                generated_config = self.create_vite_config(entry_file)
                command = ["npx", "vite", "build", "--config", str(generated_config)]
            else:
                # Fallback to npm run build (which reads vite.config.js from project root)
                command = ["npm", "run", "build"]
            subprocess.run(
                command,
                cwd=self.project_dir,
                check=True,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as e:
            raise ClientBundleError(f"Vite build failed: {e.stderr}") from e
        except FileNotFoundError:
            raise ClientBundleError(
                "npm command not found. Ensure Node.js and npm are installed."
            ) from None

    def find_bundle(self) -> Path | None:
        """Find the generated Vite bundle file.

        Returns:
            Path to the bundle file, or None if not found
        """
        for file in self.output_dir.glob("client.*.js"):
            return file
        return None

    def find_css(self) -> Path | None:
        """Find the generated Vite CSS file.

        Returns:
            Path to the CSS file, or None if not found
        """
        # Vite typically outputs CSS as main.css or with a hash
        # Try main.css first (most common), then any .css file
        css_file = self.output_dir / "main.css"
        if css_file.exists():
            return css_file
        # Fallback: find any CSS file
        for file in self.output_dir.glob("*.css"):
            return file
        return None

    def read_bundle(self) -> tuple[str, str]:
        """Read the bundled code and compute its hash.

        Returns:
            Tuple of (bundle_code, bundle_hash)

        Raises:
            ClientBundleError: If bundle file is not found
        """
        bundle_file = self.find_bundle()
        if not bundle_file:
            raise ClientBundleError("Vite build completed but no bundle file found")

        bundle_code = bundle_file.read_text(encoding="utf-8")
        bundle_hash = hashlib.sha256(bundle_code.encode("utf-8")).hexdigest()

        return bundle_code, bundle_hash

    def _has_typescript_support(self) -> bool:
        """Check if the project has TypeScript support.

        Returns:
            True if TypeScript is configured, False otherwise
        """
        tsconfig_path = self.project_dir / "tsconfig.json"
        if tsconfig_path.exists():
            return True

        # Check if @vitejs/plugin-react is in devDependencies
        package_json_path = self.project_dir / "package.json"
        if package_json_path.exists():
            import json

            try:
                with package_json_path.open() as f:
                    package_data = json.load(f)
                    dev_deps = package_data.get("devDependencies", {})
                    if "@vitejs/plugin-react" in dev_deps:
                        return True
            except (json.JSONDecodeError, KeyError):
                pass

        return False

    def create_vite_config(self, entry_file: Path) -> Path:
        """Create vite.config.js from config.json during bundling.

        Args:
            entry_file: Path to the entry file (build/main.js)

        Returns:
            Path to the created vite.config.js file
        """
        configs_dir = self.project_dir / ".jac-client.configs"
        configs_dir.mkdir(exist_ok=True)

        # Load configuration (returns defaults if config.json doesn't exist)
        vite_config_data = self.config_loader.get_vite_config()

        config_path = configs_dir / "vite.config.js"

        has_ts = self._has_typescript_support()
        # Get relative paths from project root
        try:
            entry_relative = entry_file.relative_to(self.project_dir).as_posix()
        except ValueError:
            entry_relative = entry_file.as_posix()

        try:
            output_relative = self.output_dir.relative_to(self.project_dir).as_posix()
        except ValueError:
            output_relative = self.output_dir.as_posix()

        # Build plugins array and imports
        plugins = []
        plugin_imports = []

        # Add base plugins
        if has_ts:
            plugin_imports.append('import react from "@vitejs/plugin-react";')
            plugins.append("    react()")

        # Add lib_imports from config (user-provided import statements)
        lib_imports = vite_config_data.get("lib_imports", [])
        for lib_import in lib_imports:
            if isinstance(lib_import, str) and lib_import.strip():
                plugin_imports.append(lib_import)

        # Add custom plugins from config
        custom_plugins = vite_config_data.get("plugins", [])
        for plugin in custom_plugins:
            # Plugin must be a string (function call like "tailwindcss()")
            if isinstance(plugin, str):
                # Direct function call (e.g., "tailwindcss()" or "tailwindcss({...})")
                plugins.append(f"    {plugin}")

        plugins_str = ",\n".join(plugins) if plugins else ""
        imports_str = "\n".join(plugin_imports) if plugin_imports else ""

        # Build extensions array
        extensions = [".mjs", ".js"]
        if has_ts:
            extensions.extend([".mts", ".ts", ".jsx", ".tsx"])
        extensions.append(".json")
        extensions_str = ", ".join(f'"{ext}"' for ext in extensions)

        # Build options - object format only
        build_config = vite_config_data.get("build", {})
        if isinstance(build_config, dict) and build_config:
            build_overrides_str = self._format_config_object(build_config, indent=4)
        else:
            build_overrides_str = ""

        # Server options - object format only
        server_config = vite_config_data.get("server", {})
        if isinstance(server_config, dict) and server_config:
            server_config_str = self._format_config_object(server_config, indent=2)
        else:
            server_config_str = ""

        # Resolve options - object format only
        resolve_config = vite_config_data.get("resolve", {})
        if isinstance(resolve_config, dict) and resolve_config:
            resolve_overrides_str = self._format_config_object(resolve_config, indent=6)
        else:
            resolve_overrides_str = ""

        # Format imports section
        imports_section = f"{imports_str}\n" if imports_str else ""

        newline = "\n"
        # Format server config if present
        if server_config_str:
            server_section = (
                f"  server: {{{newline}{server_config_str}{newline}  }},{newline}"
            )
        else:
            server_section = ""

        config_content = f'''import {{ defineConfig }} from "vite";
import path from "path";
import {{ fileURLToPath }} from "url";
{imports_section}const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Config is in .jac-client.configs/, so go up one level to project root
const projectRoot = path.resolve(__dirname, "..");

/**
 * Vite configuration generated from config.json (in project root)
 * To customize, edit config.json instead of this file.
 */

export default defineConfig({{
  plugins: [{newline + plugins_str + newline + "  " if plugins_str else ""}],
  root: projectRoot, // base folder (project root)
  build: {{
    rollupOptions: {{
      input: path.resolve(projectRoot, "{entry_relative}"), // your compiled entry file
      output: {{
        entryFileNames: "client.[hash].js", // name of the final js file
        assetFileNames: "[name].[ext]",
      }},
    }},
    outDir: path.resolve(projectRoot, "{output_relative}"), // final bundled output
    emptyOutDir: true,
{build_overrides_str}
  }},
  publicDir: false,
{server_section}  resolve: {{
      alias: {{
        "@jac-client/utils": path.resolve(projectRoot, "compiled/client_runtime.js"),
        "@jac-client/assets": path.resolve(projectRoot, "compiled/assets"),
      }},
      extensions: [{extensions_str}],
{resolve_overrides_str}
  }},
}});
'''

        config_path.write_text(config_content, encoding="utf-8")
        return config_path

    def _get_plugin_var_name(self, plugin_name: str) -> str:
        """Get a valid JavaScript variable name from plugin module name.

        Args:
            plugin_name: Plugin module name (e.g., "@tailwindcss/vite")

        Returns:
            Valid JavaScript variable name (e.g., "tailwindcss")
        """
        # Extract the last part after / and remove @ prefix
        name = plugin_name.split("/")[-1]
        # Replace hyphens and dots with underscores
        name = name.replace("-", "_").replace(".", "_")
        # Remove @ if present
        name = name.lstrip("@")
        return name

    def _format_plugin_options(self, options: dict) -> str:
        """Format plugin options as JavaScript object string.

        Args:
            options: Plugin options dictionary

        Returns:
            Formatted JavaScript object string
        """
        if not options:
            return ""

        items = []
        for key, value in options.items():
            if isinstance(value, str):
                items.append(f"{key}: '{value}'")
            elif isinstance(value, bool):
                items.append(f"{key}: {str(value).lower()}")
            elif isinstance(value, (int, float)):
                items.append(f"{key}: {value}")
            elif isinstance(value, list):
                items.append(f"{key}: [{', '.join(repr(v) for v in value)}]")
            else:
                items.append(f"{key}: {repr(value)}")

        return "{ " + ", ".join(items) + " }"

    def _format_config_object(self, config: dict, indent: int = 0) -> str:
        """Format config object as JavaScript object string.

        Args:
            config: Configuration dictionary
            indent: Indentation level

        Returns:
            Formatted JavaScript object string
        """
        if not config:
            return ""

        indent_str = " " * indent
        items = []
        for key, value in config.items():
            if isinstance(value, str):
                items.append(f"{indent_str}  {key}: '{value}',")
            elif isinstance(value, bool):
                items.append(f"{indent_str}  {key}: {str(value).lower()},")
            elif isinstance(value, (int, float)):
                items.append(f"{indent_str}  {key}: {value},")
            elif isinstance(value, list):
                list_str = ", ".join(repr(v) for v in value)
                items.append(f"{indent_str}  {key}: [{list_str}],")
            elif isinstance(value, dict):
                nested = self._format_config_object(value, indent + 2)
                items.append(f"{indent_str}  {key}: {{\n{nested}\n{indent_str}  }},")
            else:
                items.append(f"{indent_str}  {key}: {repr(value)},")

        return "\n".join(items)
