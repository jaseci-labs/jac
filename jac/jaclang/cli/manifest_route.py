"""Manifest-only routing for lightweight CLI paths (no registry finalize)."""

from __future__ import annotations

import os
import platform
import sys
import tomllib
from pathlib import Path

from jaclang.cli.manifest import TOMBSTONED_VERBS, known_command_names
from jaclang.cli.manifest_help import (
    _use_color,
    format_curated_help,
    format_logo,
    format_verbose_help,
)


def _read_version_from_toml(toml_path: Path) -> str | None:
    try:
        data = tomllib.loads(toml_path.read_text(encoding="utf-8"))
        project = data.get("project", {})
        if isinstance(project, dict):
            ver = project.get("version")
            if isinstance(ver, str) and ver:
                return ver
    except Exception:
        pass
    return None


def resolve_cli_version() -> str:
    """Resolve jac version without JacConfig.load."""
    dev_source = os.environ.get("JAC_DEV_SOURCE")
    if dev_source:
        toml_path = Path(dev_source) / "jac.toml"
        if toml_path.exists():
            ver = _read_version_from_toml(toml_path)
            if ver:
                return ver

    # Source checkout fallback (e.g. dev tree on sys.path without wheel metadata).
    source_toml = Path(__file__).resolve().parents[2] / "jac.toml"
    if source_toml.exists():
        ver = _read_version_from_toml(source_toml)
        if ver:
            return ver

    from importlib.metadata import version as pkg_version

    return pkg_version("jaclang")


def _first_command_token(raw_argv: list[str]) -> str | None:
    for tok in raw_argv:
        if not tok.startswith("-"):
            return tok
    return None


def _looks_like_script_token(tok: str) -> bool:
    return not tok.startswith("-") and tok.lower().endswith((".jac", ".py", ".jab"))


def _has_script_file(raw_argv: list[str]) -> bool:
    return any(_looks_like_script_token(tok) for tok in raw_argv)


def _write_stdout(text: str) -> None:
    sys.stdout.write(text)
    if not text.endswith("\n"):
        sys.stdout.write("\n")


def _print_error(message: str) -> None:
    sys.stderr.write(f"error: {message}\n")


def handle_manifest_route(raw_argv: list[str]) -> bool:
    """Handle manifest-only paths. Return True when the invocation is complete."""
    if raw_argv in (["-V"], ["--version"]):
        sys_info = f"{platform.system()} {platform.machine()}"
        ver = resolve_cli_version()
        use_color = _use_color()
        bold = "\033[1m" if use_color else ""
        reset = "\033[0m" if use_color else ""
        _write_stdout(f"{bold}jac{reset} {ver}  ({sys_info})")
        return True

    if raw_argv in (["-h"], ["--help"]):
        _write_stdout(format_verbose_help())
        return True

    if not raw_argv:
        ver = resolve_cli_version()
        _write_stdout(format_logo(ver))
        _write_stdout("")
        _write_stdout(format_curated_help())
        return True

    first = _first_command_token(raw_argv)
    if first is None:
        return False

    # Hidden verbs (gen-jir-registry, nacompile, …) must still dispatch; only
    # help/error surfaces prune them via the visible set.
    dispatchable = known_command_names(include_hidden=True)
    visible = known_command_names()

    if first in TOMBSTONED_VERBS and first not in dispatchable:
        _print_error(
            f"'jac {first}' was removed in the CLI cleanup (#7255); "
            f"use: {TOMBSTONED_VERBS[first]}"
        )
        sys.exit(2)

    # Resolve the effective command. A bare script file implies `run`;
    # rewrite argv exactly as the legacy start_cli path does.
    if _has_script_file(raw_argv) and first not in dispatchable:
        sys.argv = [sys.argv[0], "run"] + raw_argv
        command_name = "run"
    elif first in dispatchable:
        command_name = first
    else:
        choices = "', '".join(sorted(visible))
        sys.stderr.write("usage: jac [-h] [-V] COMMAND ...\n")
        _print_error(
            f"argument COMMAND: invalid choice: {first!r} (choose from '{choices}')"
        )
        sys.exit(2)

    # Phase 2: lazy dispatch -- import only the selected command's modules,
    # skipping register_feature_commands()/registry.finalize().
    from jaclang.cli.dispatch import run_selected_command

    run_selected_command(command_name)
    return True
