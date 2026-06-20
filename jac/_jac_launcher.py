"""Pure-Python launcher for the ``jac`` command (the console-script entry).

This module is the front door for every ``jac`` invocation. It is intentionally
a *top-level* module (like ``_jac_finder``), NOT part of the ``jaclang`` package:
importing anything under ``jaclang`` runs ``jaclang/__init__.py``, which eagerly
discovers and loads plugins from the *current* environment. The whole point of
the launcher is to decide -- before any of that happens -- whether the real CLI
should run inside the project's own ``.jac/venv`` instead.

Model: when a project ``jac.toml`` declares dependencies (or a plugin-backed
kind), or already has a ``.jac/venv``, the launcher ensures that venv is
provisioned (jaclang + the declared plugins/deps) and re-execs the real CLI
*inside* it via ``<venv>/bin/python -m jaclang``. This gives a single, hermetic
``jaclang`` per project -- the developer only ever ``pip install jaclang``
globally; everything else is provisioned per-project from ``jac.toml``.

Fast paths (no provisioning, run the CLI in-process on the global jaclang):
  * no ``jac.toml`` found (one-off scripts, notebooks) -- zero ceremony
  * ``JAC_NO_VENV=1`` -- full escape hatch (e.g. editable monorepo dev loop)
  * already running inside the target venv (``JAC_IN_VENV=1``)
  * env-independent subcommands (``purge``)
  * a project that declares nothing to provision and has no venv yet

Only the stdlib is imported here (os, sys, tomllib, hashlib, json, venv,
subprocess, shutil) -- never ``jaclang`` until the in-process fall-through.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

# Kept in sync with KIND_SPECS in jaclang/project/kinds.jac. Only the
# plugin-backed kinds matter here (core kinds map to no plugin).
_KIND_PLUGIN = {
    "fullstack": "jac-client",
    "client": "jac-client",
    "mobile": "jac-client",
    "desktop": "jac-desktop",
}

# Subcommands that must never trigger provisioning/re-exec -- they are
# environment-independent and must work even with a broken/absent venv.
_SKIP_COMMANDS = {"purge"}


def _find_project_root(start: Path) -> Path | None:
    """Walk upward from ``start`` for a directory containing ``jac.toml``.

    Mirrors jaclang.project.config.find_project_root in pure Python.
    """
    current = start.resolve()
    while True:
        if (current / "jac.toml").exists():
            return current
        if current == current.parent:
            return None
        current = current.parent


def _load_toml(path: Path) -> dict:
    import tomllib

    try:
        with open(path, "rb") as f:
            return tomllib.load(f)
    except Exception:
        # Malformed jac.toml: let the in-process CLI surface the actionable
        # error banner. The launcher must not crash here.
        return {}


def _first_positional(argv: list[str]) -> str | None:
    """First non-flag token (the subcommand), skipping leading options."""
    for tok in argv:
        if not tok.startswith("-"):
            return tok
    return None


def _venv_python(venv_dir: Path) -> Path:
    if sys.platform == "win32":
        return venv_dir / "Scripts" / "python.exe"
    return venv_dir / "bin" / "python"


def _make_pip_spec(name: str, version: str) -> str:
    """Mirror DependencyInstaller._make_pip_spec."""
    if not version or version in ("*", "latest"):
        return name
    if version[:1] in ("=", ">", "<", "~", "!"):
        return f"{name}{version}"
    return f"{name}=={version}"


def _collect_specs(toml: dict, kind_plugin: str | None) -> list[str]:
    """Build the pip spec list for provisioning a project venv.

    Always includes ``jaclang`` (the venv must be self-contained so
    ``python -m jaclang`` works after re-exec), plus the kind's plugin and
    every entry in ``[dependencies]``. Git deps are appended as ``git+`` specs.
    """
    specs: list[str] = ["jaclang"]
    if kind_plugin:
        specs.append(kind_plugin)
    deps = toml.get("dependencies", {})
    if isinstance(deps, dict):
        for name, version in deps.items():
            if name == "git" or isinstance(version, dict):
                continue  # nested tables ([dependencies.git]/[.npm]) handled below
            specs.append(_make_pip_spec(name, str(version)))
        git = deps.get("git", {})
        if isinstance(git, dict):
            for _, info in git.items():
                if isinstance(info, dict) and info.get("git"):
                    branch = info.get("branch", "")
                    url = info["git"]
                    specs.append(f"git+{url}@{branch}" if branch else f"git+{url}")
    # De-dup preserving order.
    seen: set[str] = set()
    out: list[str] = []
    for s in specs:
        if s not in seen:
            seen.add(s)
            out.append(s)
    return out


def _lock_payload(specs: list[str]) -> dict:
    """Inputs whose change should invalidate the provisioned venv."""
    import importlib.metadata as md

    try:
        jaclang_version = md.version("jaclang")
    except Exception:
        jaclang_version = "unknown"
    return {
        "specs": sorted(specs),
        "jaclang_version": jaclang_version,
        "py": f"{sys.version_info.major}.{sys.version_info.minor}",
    }


def _lock_hash(payload: dict) -> str:
    import hashlib
    import json

    blob = json.dumps(payload, sort_keys=True).encode()
    return hashlib.sha256(blob).hexdigest()


def _read_lock(lock_path: Path) -> str | None:
    import json

    try:
        return json.loads(lock_path.read_text()).get("hash")
    except Exception:
        return None


def _write_lock(lock_path: Path, payload: dict, digest: str) -> None:
    import contextlib
    import json

    with contextlib.suppress(Exception):
        lock_path.write_text(json.dumps({"hash": digest, **payload}, indent=2))


def _provision(venv_dir: Path, specs: list[str]) -> bool:
    """Create the project venv (if needed) and install ``specs`` into it.

    Returns True on success. Prefers ``uv pip`` when available; falls back to
    the venv's own pip. Pure stdlib -- does not import jaclang.
    """
    import shutil
    import subprocess
    import venv as venv_mod

    py = _venv_python(venv_dir)
    pyvenv_cfg = venv_dir / "pyvenv.cfg"
    if not (pyvenv_cfg.exists() and py.exists()):
        if venv_dir.exists():
            shutil.rmtree(venv_dir, ignore_errors=True)
        venv_dir.parent.mkdir(parents=True, exist_ok=True)
        sys.stderr.write(f"jac: provisioning project environment ({venv_dir})...\n")
        try:
            venv_mod.EnvBuilder(
                with_pip=True, symlinks=(sys.platform != "win32")
            ).create(str(venv_dir))
        except Exception as exc:
            sys.stderr.write(f"jac: failed to create venv: {exc}\n")
            return False

    uv = shutil.which("uv") if os.environ.get("JAC_NO_UV") != "1" else None
    if uv:
        cmd = [uv, "pip", "install", "--python", str(py), *specs]
    else:
        cmd = [str(py), "-m", "pip", "install", *specs]
    try:
        result = subprocess.run(cmd)
    except Exception as exc:
        sys.stderr.write(f"jac: dependency install failed: {exc}\n")
        return False
    return result.returncode == 0


def _reexec(venv_dir: Path, argv: list[str]) -> None:
    """Replace this process with the CLI running inside the project venv."""
    py = _venv_python(venv_dir)
    env = dict(os.environ)
    env["JAC_IN_VENV"] = "1"
    os.execve(str(py), [str(py), "-m", "jaclang", *argv], env)


def _run_in_process(argv: list[str]) -> None:
    """Fall through to the real CLI on the current (global) jaclang."""
    # start_cli reads sys.argv; keep argv[0] (program name), use cleaned args.
    sys.argv = [sys.argv[0], *argv]
    from jaclang.jac0core.cli_boot import start_cli

    start_cli()


def main() -> None:
    """Console-script entry point for ``jac``."""
    raw_argv = sys.argv[1:]
    # --frozen is a launcher-only signal; strip it so the downstream CLI
    # (which doesn't define it) never sees it.
    frozen = "--frozen" in raw_argv
    argv = [a for a in raw_argv if a != "--frozen"]

    # Escape hatches and env-independent commands -> run in-process.
    if os.environ.get("JAC_NO_VENV") == "1" or os.environ.get("JAC_IN_VENV") == "1":
        _run_in_process(argv)
        return
    cmd = _first_positional(argv)
    if cmd in _SKIP_COMMANDS:
        _run_in_process(argv)
        return

    root = _find_project_root(Path.cwd())
    if root is None:
        _run_in_process(argv)
        return

    toml = _load_toml(root / "jac.toml")
    build_dir = root / str(toml.get("build", {}).get("dir", ".jac"))
    venv_dir = build_dir / "venv"
    kind = toml.get("project", {}).get("kind", "")
    kind_plugin = _KIND_PLUGIN.get(kind)
    deps = toml.get("dependencies", {})
    has_deps = isinstance(deps, dict) and len(deps) > 0

    # Nothing to provision and no existing venv -> stay in-process. This is the
    # zero-ceremony path and what keeps the editable monorepo dev loop working
    # (its root jac.toml declares no dependencies and no plugin-backed kind).
    if not venv_dir.exists() and not has_deps and not kind_plugin:
        _run_in_process(argv)
        return

    # If we're already running from inside the project venv, just run. Compare
    # WITHOUT resolving symlinks: a venv's python symlinks back to the base
    # interpreter, so .resolve() would make every venv look identical to the
    # global one. (The JAC_IN_VENV marker set by _reexec is the primary guard;
    # this also covers invoking the venv's own `jac` script directly.)
    exe = os.path.abspath(sys.executable)
    if exe.startswith(os.path.abspath(venv_dir) + os.sep):
        _run_in_process(argv)
        return

    no_sync = os.environ.get("JAC_NO_SYNC") == "1" or frozen

    specs = _collect_specs(toml, kind_plugin)
    payload = _lock_payload(specs)
    digest = _lock_hash(payload)
    lock_path = venv_dir / ".jac-lock"
    fresh = venv_dir.exists() and _read_lock(lock_path) == digest

    if not fresh:
        if no_sync:
            if venv_dir.exists():
                # Use the (possibly stale) venv as-is.
                _reexec(venv_dir, argv)
                return
            sys.stderr.write(
                "jac: project environment is not provisioned and --frozen/"
                "JAC_NO_SYNC is set; running on the global environment.\n"
            )
            _run_in_process(argv)
            return
        if _provision(venv_dir, specs):
            _write_lock(lock_path, payload, digest)
        else:
            sys.stderr.write(
                "jac: provisioning failed; falling back to the global environment.\n"
            )
            _run_in_process(argv)
            return

    _reexec(venv_dir, argv)


if __name__ == "__main__":
    main()
