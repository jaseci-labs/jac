"""Pure-Python CLI version metadata for the launcher fast paths.

This module must stay free of jaclang (and any .jac) imports: cli_boot --
a jac0 seed module -- imports it to serve ``jac --version`` before the
compiler/runtime bootstrap runs, and manifest_route delegates to it so the
two paths cannot drift. Everything here is stdlib-only.
"""

from __future__ import annotations

import os
import platform
import sys
from pathlib import Path

_TITLE = "\033[1m"
_RESET = "\033[0m"


def _read_version_from_toml(toml_path: Path) -> str | None:
    try:
        import tomllib

        data = tomllib.loads(toml_path.read_text(encoding="utf-8"))
    except Exception:
        return None
    project = data.get("project", {})
    if isinstance(project, dict):
        ver = project.get("version")
        if isinstance(ver, str) and ver:
            return ver
    return None


def resolve_cli_version(dev_source: str | None = None) -> str:
    """Resolve the jac CLI version.

    Order: the dev source tree's jac.toml (when JAC_DEV_SOURCE is engaged),
    the jac.toml packaged next to the jaclang package, then installed
    package metadata.
    """
    from importlib.metadata import version as pkg_version

    if dev_source:
        ver = _read_version_from_toml(Path(dev_source) / "jac.toml")
        if ver:
            return ver

    source_toml = Path(__file__).resolve().parent.parent / "jac.toml"
    if source_toml.exists():
        ver = _read_version_from_toml(source_toml)
        if ver:
            return ver

    return pkg_version("jaclang")


def use_emoji() -> bool:
    """Same rule as JacConsole._should_use_emoji, without importing it."""
    if os.environ.get("NO_EMOJI") or os.environ.get("TERM") == "dumb":
        return False
    if sys.platform == "win32" and not os.environ.get("WT_SESSION"):
        return False
    return True


def should_use_color() -> bool:
    """Same rule as JacConsole._should_use_color, without importing it."""
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("TERM") == "dumb":
        return False
    try:
        if not sys.stdout.isatty():
            return False
    except Exception:
        return False
    return True


def render_version_line(version: str) -> str:
    """Render the ``jac --version`` line (identical to the manifest route)."""
    use_color = should_use_color()
    name = f"{_TITLE}jac{_RESET}" if use_color else "jac"
    return f"{name} {version}  ({platform.system()} {platform.machine()})"
