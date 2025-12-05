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
    ):
        """Initialize the Vite bundler.

        Args:
            project_dir: Path to the project directory containing package.json
            output_dir: Output directory for Vite builds (defaults to compiled/dist/assets)
            minify: Whether to enable minification in Vite build
        """
        self.project_dir = project_dir
        self.output_dir = output_dir or (project_dir / "compiled" / "dist" / "assets")
        self.minify = minify

    def build(self) -> None:
        """Run Vite build (npm run build).

        Raises:
            ClientBundleError: If Vite build fails
        """
        self.output_dir.mkdir(parents=True, exist_ok=True)

        try:
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

    def generate_vite_config(self, entry_file: Path) -> str:
        """Generate Vite configuration for bundling.

        Args:
            entry_file: Path to the entry file

        Returns:
            Vite configuration as a string
        """
        entry_name = entry_file.as_posix()
        output_dir_name = self.output_dir.as_posix()
        minify_setting = "true" if self.minify else "false"

        return f"""
            import {{ defineConfig }} from 'vite';
            import {{ resolve }} from 'path';

            export default defineConfig({{
            build: {{
                outDir: '{output_dir_name}',
                emptyOutDir: true,
                rollupOptions: {{
                input: {{
                    main: resolve(__dirname, '{entry_name}'),
                }},
                output: {{
                    entryFileNames: 'client.[hash].js',
                    format: 'iife',
                    name: 'JacClient',
                }},
                }},
                minify: {minify_setting}, // Configurable minification
            }},
            resolve: {{
            }}
            }});
        """
