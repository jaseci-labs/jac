"""Configuration loader for Jac Client build system."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from jaclang.runtimelib.client_bundle import ClientBundleError


class JacClientConfig:
    """Manages Jac Client configuration from config.json."""

    def __init__(self, project_dir: Path):
        """Initialize config loader.

        Args:
            project_dir: Path to the project directory
        """
        self.project_dir = project_dir
        self.configs_dir = project_dir / ".jac-client.configs"
        self.config_file = project_dir / "config.json"  # Config is in project root
        self._config: dict[str, Any] | None = None

    def _get_default_config(self) -> dict[str, Any]:
        """Get default configuration structure.

        Returns:
            Default config dictionary with all predefined keys

        Note:
            Configuration format:
            - "plugins": array of strings with function calls (e.g., ["tailwindcss()"])
            - "lib_imports": array of import statements (e.g., ["import tailwindcss from '@tailwindcss/vite'"])
            - "build": object with build options (e.g., {"sourcemap": true, "minify": "esbuild"})
            - "server": object with server options (e.g., {"port": 3000, "open": true})
            - "resolve": object with resolve options (e.g., {"dedupe": ["react", "react-dom"]})
        """
        return {
            "vite": {
                "plugins": [],  # Array of plugin function calls (e.g., ["tailwindcss()"])
                "lib_imports": [],  # Array of import statements (e.g., ["import tailwindcss from '@tailwindcss/vite'"])
                "build": {},  # Build options object
                "server": {},  # Server options object
                "resolve": {},  # Resolve options object
            },
            "ts": {
                # Future TypeScript config options
            },
        }

    def load(self) -> dict[str, Any]:
        """Load configuration from config.json, merging with defaults.

        Returns:
            Merged configuration dictionary
        """
        if self._config is not None:
            return self._config

        default_config = self._get_default_config()

        # If config file doesn't exist, return defaults
        if not self.config_file.exists():
            self._config = default_config
            return self._config

        # Load user config
        try:
            with self.config_file.open(encoding="utf-8") as f:
                user_config = json.load(f)
        except json.JSONDecodeError as e:
            raise ClientBundleError(f"Invalid JSON in {self.config_file}: {e}") from e
        except Exception as e:
            raise ClientBundleError(
                f"Error reading config file {self.config_file}: {e}"
            ) from e

        # Deep merge user config with defaults
        self._config = self._deep_merge(default_config, user_config)
        return self._config

    def _deep_merge(
        self, base: dict[str, Any], override: dict[str, Any]
    ) -> dict[str, Any]:
        """Deep merge two dictionaries.

        Args:
            base: Base dictionary
            override: Override dictionary

        Returns:
            Merged dictionary
        """
        result = base.copy()

        for key, value in override.items():
            if (
                key in result
                and isinstance(result[key], dict)
                and isinstance(value, dict)
            ):
                result[key] = self._deep_merge(result[key], value)
            else:
                result[key] = value

        return result

    def get_vite_config(self) -> dict[str, Any]:
        """Get Vite-specific configuration.

        Returns:
            Vite configuration dictionary
        """
        config = self.load()
        return config.get("vite", {})

    def get_ts_config(self) -> dict[str, Any]:
        """Get TypeScript-specific configuration.

        Returns:
            TypeScript configuration dictionary
        """
        config = self.load()
        return config.get("ts", {})
