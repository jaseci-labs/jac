"""Babel processing for JavaScript transpilation."""

from __future__ import annotations

import subprocess
from pathlib import Path

from jaclang.runtimelib.client_bundle import ClientBundleError


class BabelProcessor:
    """Handles Babel compilation of JavaScript files."""

    def __init__(self, project_dir: Path):
        """Initialize the Babel processor.

        Args:
            project_dir: Path to the project directory containing package.json
        """
        self.project_dir = project_dir

    def compile(self) -> None:
        """Run Babel compilation (npm run compile).

        Raises:
            ClientBundleError: If Babel compilation fails
        """
        try:
            command = ["npm", "run", "compile"]
            result = subprocess.run(
                command,
                cwd=self.project_dir,
                check=True,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as e:
            raise ClientBundleError(
                f"Babel compilation failed: {e.stderr}"
            ) from e
        except FileNotFoundError:
            raise ClientBundleError(
                "npm command not found. Ensure Node.js and npm are installed."
            ) from None

    def copy_assets_after_compile(
        self, compiled_dir: Path, build_dir: Path, asset_processor
    ) -> None:
        """Copy CSS and other asset files from compiled/ to build/ after Babel compilation.

        Babel only transpiles JS, so we need to manually copy assets.

        Args:
            compiled_dir: Directory containing compiled files
            build_dir: Directory to copy assets to
            asset_processor: AssetProcessor instance for copying assets
        """
        asset_processor.copy_assets(compiled_dir, build_dir)

