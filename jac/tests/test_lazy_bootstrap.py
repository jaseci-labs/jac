"""Tests for the two-tier lazy bootstrap and the plugin-manager compat surface.

The lazy path (bare ``import jaclang`` -> first hook -> ``ensure_for_hook`` ->
``bootstrap_product``) is the *production* path, but the test suite pins
``JAC_EAGER_BOOTSTRAP=1`` (see the repo-root ``conftest.py``), so the parent
pytest process is already eagerly bootstrapped. These tests therefore drive the
lazy path in a clean child interpreter via ``subprocess`` with the eager flag
removed from the environment.
"""

from __future__ import annotations

import os
import subprocess
import sys

import pytest


def _run(code: str, *, eager: bool | None) -> subprocess.CompletedProcess[str]:
    """Run ``code`` in a fresh interpreter, controlling the eager-bootstrap flag.

    ``eager=None`` removes ``JAC_EAGER_BOOTSTRAP`` from the child env (the real
    lazy path); ``eager=True`` sets it to ``"1"``.
    """
    env = dict(os.environ)
    env.pop("JAC_EAGER_BOOTSTRAP", None)
    if eager:
        env["JAC_EAGER_BOOTSTRAP"] = "1"
    return subprocess.run(
        [sys.executable, "-c", code],
        env=env,
        capture_output=True,
        text=True,
        timeout=300,
    )


def _assert_ok(proc: subprocess.CompletedProcess[str]) -> None:
    assert proc.returncode == 0, (
        f"child exited {proc.returncode}\n--- stdout ---\n{proc.stdout}\n"
        f"--- stderr ---\n{proc.stderr}"
    )
    assert proc.stdout.strip().splitlines()[-1] == "OK", proc.stdout


def test_bare_import_does_not_bootstrap_product() -> None:
    """A bare ``import jaclang`` runs only the kernel tier, not the product tier."""
    proc = _run(
        """
import jaclang
from jaclang.bootstrap import is_product_bootstrapped, is_product_settled
assert is_product_bootstrapped() is False, "product bootstrapped at import"
assert is_product_settled() is False, "product settled at import"
print("OK")
""",
        eager=None,
    )
    _assert_ok(proc)


def test_hook_dispatch_triggers_product_bootstrap() -> None:
    """Dispatching any @hookable after a bare import triggers product bootstrap."""
    proc = _run(
        """
import jaclang
from jaclang.bootstrap import is_product_bootstrapped
from jaclang.jac0core.runtime import JacRuntime as Jac
assert not is_product_bootstrapped()
# get_sv_registry is a no-arg, side-effect-free @hookable; calling it must run
# the lazy product bootstrap through the dispatch proxy's ensure_for_hook.
Jac.get_sv_registry()
assert is_product_bootstrapped(), "hook dispatch did not bootstrap product"
print("OK")
""",
        eager=None,
    )
    _assert_ok(proc)


def test_eager_env_bootstraps_at_import() -> None:
    """``JAC_EAGER_BOOTSTRAP=1`` restores eager product bootstrap at import time."""
    proc = _run(
        """
import jaclang
from jaclang.bootstrap import is_product_bootstrapped
assert is_product_bootstrapped(), "eager flag did not bootstrap at import"
print("OK")
""",
        eager=True,
    )
    _assert_ok(proc)


def test_failed_bootstrap_stamps_failed_and_never_retries() -> None:
    """A failing bootstrap latches FAILED, warns once, and is not retried."""
    proc = _run(
        """
import warnings
import jaclang.bootstrap as b

# Force a fresh, deliberately-failing product bootstrap.
b._PRODUCT_STATE = b._BootstrapState.IDLE
calls = {"n": 0}
def boom(_pm):
    calls["n"] += 1
    raise RuntimeError("boom")
b._register_builtin_client_providers = boom

with warnings.catch_warnings(record=True) as caught:
    warnings.simplefilter("always")
    b.bootstrap_product()   # fails -> FAILED (swallowed, one warning)
    b.bootstrap_product()   # terminal -> no-op, no re-run
    b.ensure_for_hook()     # terminal -> no-op, no re-run

assert b._PRODUCT_STATE == b._BootstrapState.FAILED, b._PRODUCT_STATE
assert b.is_product_settled() is True
assert b.is_product_bootstrapped() is False
# The failing provider ran exactly once: no retry across the three calls.
assert calls["n"] == 1, calls
boom_warnings = [w for w in caught if "product bootstrap failed" in str(w.message)]
assert len(boom_warnings) == 1, [str(w.message) for w in caught]
print("OK")
""",
        eager=None,
    )
    _assert_ok(proc)


def test_pluggy_style_hookimpl_marker_is_recognized() -> None:
    """A plugin marked with a real pluggy ``HookimplMarker('jac')`` registers.

    Real pluggy stamps ``<project_name>_impl`` (``jac_impl``) rather than our
    ``_jac_hookimpl``; ``PluginManager.register`` must honor both or such a
    plugin registers with zero hooks, silently.
    """
    from jaclang.jac0core.plugin import PluginManager

    pm = PluginManager("jac")

    def _some_hook_fn() -> str:
        return "pluggy-impl-ran"

    # Emulate pluggy.HookimplMarker("jac"): it stamps the `<project>_impl`
    # (`jac_impl`) attribute on the underlying function, then it is exposed as a
    # staticmethod on the plugin class.
    _some_hook_fn.jac_impl = {}  # type: ignore[attr-defined]

    class _PluggyStylePlugin:
        some_hook = staticmethod(_some_hook_fn)

    pm.register(_PluggyStylePlugin)
    hook = getattr(pm.hook, "some_hook", None)
    assert hook is not None, "pluggy-style hookimpl was not registered"
    assert hook() == ["pluggy-impl-ran"]


def test_native_hookimpl_marker_still_recognized() -> None:
    """The in-tree ``_jac_hookimpl`` marker keeps working alongside pluggy's."""
    from jaclang.jac0core.plugin import HookimplMarker, PluginManager

    pm = PluginManager("jac")
    hookimpl = HookimplMarker("jac")

    class _NativePlugin:
        @staticmethod
        @hookimpl
        def some_hook() -> str:
            return "native-impl-ran"

    pm.register(_NativePlugin)
    hook = getattr(pm.hook, "some_hook", None)
    assert hook is not None
    assert hook() == ["native-impl-ran"]


@pytest.mark.parametrize(
    "args,kwargs,expected",
    [
        ((), {}, {"base_path": "./storage", "create_dirs": True}),
        (("/tmp/x",), {}, {"base_path": "/tmp/x", "create_dirs": True}),
        (("/tmp/x", False), {}, {"base_path": "/tmp/x", "create_dirs": False}),
        ((), {"create_dirs": False}, {"base_path": "./storage", "create_dirs": False}),
    ],
)
def test_hook_proxy_fast_path_matches_bind_partial(
    args: tuple, kwargs: dict, expected: dict
) -> None:
    """The precomputed dispatch fast path yields the same kwargs as bind_partial.

    The proxy replaced per-call ``Signature.bind_partial`` + ``apply_defaults``
    with a precomputed positional-name/default mapping. This pins that the
    reconstructed keyword arguments are identical for the ``store`` hook (which
    has positional-or-keyword params with defaults) across positional/keyword
    call shapes.
    """
    import inspect

    from jaclang.jac0core.runtime import JacRuntimeInterface

    sig = inspect.signature(JacRuntimeInterface.store)
    reference = sig.bind_partial(*args, **kwargs)
    reference.apply_defaults()
    assert dict(reference.arguments) == expected


# ---------------------------------------------------------------------------
# Lazy subcommand loading
# ---------------------------------------------------------------------------


def test_version_flag_skips_bootstrap() -> None:
    """``jac --version`` exits without calling ``bootstrap_product``."""
    proc = _run(
        """
import sys, os
sys.argv = ["jac", "--version"]

import jaclang.bootstrap as b
orig = b.bootstrap_product
called = {"n": 0}
def spy():
    called["n"] += 1
    orig()
b.bootstrap_product = spy

from jaclang.cli.cli import start_cli
try:
    start_cli()
except SystemExit:
    pass

assert called["n"] == 0, f"bootstrap_product called {called['n']} time(s)"
print("OK")
""",
        eager=None,
    )
    _assert_ok(proc)


def test_version_flag_prints_version() -> None:
    """``jac --version`` produces output without crashing."""
    proc = _run(
        """
import sys
sys.argv = ["jac", "--version"]
from jaclang.cli.cli import start_cli
try:
    start_cli()
except SystemExit:
    pass
print("OK")
""",
        eager=None,
    )
    assert proc.returncode == 0, proc.stderr
    assert "OK" in proc.stdout
    # Must print something version-like (a non-empty banner line)
    non_ok = [
        ln for ln in proc.stdout.splitlines() if ln.strip() and ln.strip() != "OK"
    ]
    assert non_ok, f"no version output found: {proc.stdout!r}"


def test_manifest_has_all_core_commands() -> None:
    """The manifest covers the expected set of built-in command names."""
    from jaclang.cli._cmd_manifest import MANIFEST

    names = {e["name"] for e in MANIFEST}
    for expected in ("run", "check", "fmt", "test", "build", "create", "install"):
        assert expected in names, f"command {expected!r} missing from manifest"


def test_manifest_commands_have_required_fields() -> None:
    """Every manifest entry has name, help, group, module, and args fields."""
    from jaclang.cli._cmd_manifest import MANIFEST

    for entry in MANIFEST:
        assert "name" in entry, entry
        assert "help" in entry, entry
        assert "group" in entry, entry
        assert "module" in entry, entry
        assert "args" in entry, entry
        assert entry["module"].startswith("jaclang.cli.commands."), entry


def test_registry_load_from_manifest() -> None:
    """``load_from_manifest`` populates the registry without importing command modules."""
    from jaclang.cli._cmd_manifest import MANIFEST
    from jaclang.cli.registry import CommandRegistry

    reg = CommandRegistry()
    reg.load_from_manifest(MANIFEST)

    assert len(reg.commands) == len(MANIFEST)
    spec = reg.get("run")
    assert spec is not None
    assert spec.handler is None
    assert spec.module == "jaclang.cli.commands.execution"
    assert any(a.name == "filename" for a in spec.args)


def test_registry_load_from_manifest_is_idempotent() -> None:
    """Calling ``load_from_manifest`` twice doesn't duplicate or overwrite specs."""
    from jaclang.cli._cmd_manifest import MANIFEST
    from jaclang.cli.registry import CommandRegistry

    reg = CommandRegistry()
    reg.load_from_manifest(MANIFEST)
    first_spec = reg.get("run")
    reg.load_from_manifest(MANIFEST)
    assert reg.get("run") is first_spec, "load_from_manifest replaced an existing spec"
    assert len(reg.commands) == len(MANIFEST)
