"""Vite bundling module."""

from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

from jaclang.runtimelib.client_bundle import ClientBundleError


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
        """Create vite.config.js in .jac-client.configs/ directory during bundling.

        Args:
            entry_file: Path to the entry file (build/main.js)

        Returns:
            Path to the created vite.config.js file
        """
        configs_dir = self.project_dir / ".jac-client.configs"
        configs_dir.mkdir(exist_ok=True)
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

        if has_ts:
            config_content = f'''import {{ defineConfig }} from "vite";
import path from "path";
import {{ fileURLToPath }} from "url";
import react from "@vitejs/plugin-react";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Config is in .jac-client.configs/, so go up one level to project root
const projectRoot = path.resolve(__dirname, "..");

export default defineConfig({{
  plugins: [react()],
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
  }},
  publicDir: false,
  resolve: {{
      alias: {{
        "@jac-client/utils": path.resolve(projectRoot, "compiled/client_runtime.js"),
        "@jac-client/assets": path.resolve(projectRoot, "compiled/assets"),
      }},
      extensions: [".mjs", ".js", ".mts", ".ts", ".jsx", ".tsx", ".json"],
  }},
}});
'''
        else:
            config_content = f'''import {{ defineConfig }} from "vite";
import path from "path";
import {{ fileURLToPath }} from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Config is in .jac-client.configs/, so go up one level to project root
const projectRoot = path.resolve(__dirname, "..");

export default defineConfig({{
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
  }},
  publicDir: false,
  resolve: {{
      alias: {{
        "@jac-client/utils": path.resolve(projectRoot, "compiled/client_runtime.js"),
        "@jac-client/assets": path.resolve(projectRoot, "compiled/assets"),
      }},
  }},
}});
'''

        config_path.write_text(config_content, encoding="utf-8")
        return config_path
