"""Two-tier bootstrap for jaclang.

Import-time work is split into two tiers so ``import jaclang`` stays cheap:

* :func:`bootstrap_kernel` -- the cheap tier. Registers the Jac meta-importer
  and the core ``JacRuntime`` plugin. This is the *only* thing
  ``import jaclang`` runs.
* :func:`bootstrap_product` -- the heavier tier. Registers the built-in
  providers (client / shadcn / scale / mcp / byllm), loads external entry-point
  plugins, and schedules native acceleration. It is triggered *lazily*:

  - explicitly by the CLI (``start_cli`` calls it before
    ``register_feature_commands``),
  - on the first hook dispatch (:func:`ensure_for_hook`, wired into the
    runtime's hook-dispatch proxy), or
  - eagerly up-front when ``JAC_EAGER_BOOTSTRAP=1`` is set (transition shim
    for callers -- e.g. the test suite -- that still assume eager plugins).

Splitting these tiers is what lets a bare ``import jaclang``, ``jac --version``,
and ``jac purge`` (short-circuited in ``jaclang.jac0core.cli_boot.start_cli``
before the product CLI ever loads) avoid pulling the entire product surface
(client framework, scale, byllm, LLVM bindings, ``jaclang.project.config`` ...)
at startup. ``start_cli`` short-circuits ``--version`` / ``-V`` before
:func:`bootstrap_product` and defers feature command registration to
:func:`jaclang.cli.registry.register_feature_commands` only when a real command
is about to run.
"""

from __future__ import annotations

import contextlib
import enum
import sys
import threading
import warnings


class _BootstrapState(enum.Enum):
    IDLE = "idle"
    BOOTSTRAPPING = "bootstrapping"
    DONE = "done"
    FAILED = "failed"


# Product-bootstrap state machine: IDLE -> BOOTSTRAPPING -> {DONE, FAILED}.
#
# DONE and FAILED are both *terminal*: once bootstrap has run we never attempt
# it again this process. A run that raises stamps FAILED (not IDLE) and emits a
# single warning -- previously it reset to IDLE, so every subsequent hook
# dispatch re-ran the whole failing bootstrap and re-logged the warning, which
# is pathological in a hot loop. Product bootstrap is deterministic within a
# process (same env, same installed plugins), so a failure that happens once
# will happen every time; retrying buys nothing but noise.
#
# The BOOTSTRAPPING state makes ``ensure_for_hook`` re-entrancy-safe: a hook
# fired *during* ``bootstrap_product()`` (e.g. by a plugin running code at
# registration time, or by the native-accel scheduler) must not re-enter
# ``bootstrap_product()`` and recurse. While bootstrapping, hook dispatch
# proceeds against whatever providers have been registered so far -- which is
# the same partial-registration behaviour the old eager ``__init__`` exhibited.
_PRODUCT_STATE = _BootstrapState.IDLE
_PRODUCT_LOCK = threading.RLock()

# Terminal states: no further bootstrap attempts are made once reached.
_SETTLED_STATES = (_BootstrapState.DONE, _BootstrapState.FAILED)


def bootstrap_kernel() -> None:
    """Register the Jac meta-importer and the core JacRuntime plugin.

    Idempotent. This is the only work ``import jaclang`` performs; everything
    product-facing is deferred to :func:`bootstrap_product`.
    """
    from jaclang.meta_importer import JacMetaImporter

    # Register the meta-importer BEFORE loading any .jac module so .jac imports
    # resolve through it.
    if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
        sys.meta_path.insert(0, JacMetaImporter())

    # Import compiler first to ensure generated parsers exist before
    # jac0core.parser is loaded. Backwards-compatible import path for older
    # plugins/tests; prefer jaclang.jac0core.runtime going forward.
    import jaclang.jac0core.runtime as _runtime_mod  # noqa: F401
    from jaclang import compiler as _compiler  # noqa: F401
    from jaclang.jac0core.runtime import JacRuntimeImpl, plugin_manager

    # Compatibility alias: older code imports jaclang.runtimelib.runtime.
    sys.modules.setdefault("jaclang.runtimelib.runtime", _runtime_mod)

    if not plugin_manager.is_registered(JacRuntimeImpl):
        plugin_manager.register(JacRuntimeImpl)

    # Put the current project's .jac/venv on sys.path BEFORE enumerating
    # plugins, so per-project plugins (jac install [-e] <pkg>) are discovered.
    # In the single binary this already ran via sitecustomize during interpreter
    # startup; this call is the library-use fallback (plain `import jaclang`
    # with no sitecustomize). Idempotent; uses addsitedir so .pth links resolve.
    with contextlib.suppress(Exception):
        import _jac_finder as _jf

        _jf.add_project_venv_to_path()


def bootstrap_product() -> None:
    """Register built-in providers, external plugins, and native acceleration.

    Idempotent, re-entrancy-safe, and run-once: a failing run is not retried
    (it stamps FAILED and warns once). Normally triggered lazily via
    :func:`ensure_for_hook` or explicitly by the CLI; opt into eager behaviour
    with ``JAC_EAGER_BOOTSTRAP=1``.
    """
    global _PRODUCT_STATE
    if _PRODUCT_STATE in _SETTLED_STATES:
        return
    with _PRODUCT_LOCK:
        if _PRODUCT_STATE in _SETTLED_STATES:
            return
        if _PRODUCT_STATE == _BootstrapState.BOOTSTRAPPING:
            # Re-entrant call from the same thread (a hook fired during
            # registration). With RLock the same thread can re-acquire the lock,
            # so we reach here instead of deadlocking. Don't recurse; let
            # dispatch proceed against the partially-registered plugin set.
            return
        _PRODUCT_STATE = _BootstrapState.BOOTSTRAPPING
        try:
            from jaclang.jac0core.helpers import (
                get_disabled_plugins,
                load_plugins_with_disabling,
            )
            from jaclang.jac0core.runtime import plugin_manager

            try:
                load_plugins_with_disabling(plugin_manager, get_disabled_plugins())
            except Exception as exc:
                warnings.warn(f"External plugin loading failed: {exc}", stacklevel=2)

            _register_builtin_client_providers(plugin_manager)
            _register_builtin_scale_provider(plugin_manager)
            _register_builtin_mcp_provider(plugin_manager)
            _register_builtin_byllm_provider(plugin_manager)

            _maybe_schedule_native_accel()
            _PRODUCT_STATE = _BootstrapState.DONE
        except Exception as exc:
            # Terminal failure: stamp FAILED (not IDLE) so we never retry, and
            # warn exactly once instead of on every subsequent hook dispatch.
            _PRODUCT_STATE = _BootstrapState.FAILED
            warnings.warn(
                f"Jac product bootstrap failed; product providers are disabled for "
                f"this process (core remains usable): {exc}",
                stacklevel=2,
            )


def is_product_bootstrapped() -> bool:
    """Return True once :func:`bootstrap_product` has completed successfully."""
    return _PRODUCT_STATE == _BootstrapState.DONE


def is_product_settled() -> bool:
    """Return True once product bootstrap has reached a terminal state.

    Terminal means either DONE (succeeded) or FAILED (won't be retried). Callers
    that want to latch a one-time fast path -- e.g. the runtime's hook-dispatch
    proxy -- should gate on this, not on :func:`is_product_bootstrapped`, so a
    failed bootstrap latches too and stops re-triggering the lazy path.
    """
    return _PRODUCT_STATE in _SETTLED_STATES


def ensure_for_hook() -> None:
    """Ensure product-tier providers are registered before a hook dispatches.

    Called from the hook-dispatch proxy in ``jaclang.jac0core.runtime`` so that
    library code or tests invoking ``Jac.<hook>(...)`` after a bare
    ``import jaclang`` still resolve every provider -- without paying for that
    registration at import time. Idempotent and re-entrancy-safe.

    Only attempts bootstrap from IDLE: once the state is terminal (DONE or
    FAILED) or already BOOTSTRAPPING, this is a no-op, so a failed bootstrap is
    never retried on later hook dispatches.
    """
    if _PRODUCT_STATE == _BootstrapState.IDLE:
        bootstrap_product()


# --------------------------------------------------------------------------- #
# Built-in provider registration (moved out of __init__.py).
#
# Each helper degrades gracefully: if a provider's module fails to import, the
# core stays usable and a warning is emitted (mirroring the old __init__).
# --------------------------------------------------------------------------- #


def _register_builtin_client_providers(plugin_manager: object) -> None:
    """Register the built-in client/desktop framework hook providers.

    These shipped as the separate ``jac-client`` / ``jac-desktop`` plugins; they
    are now part of core and register directly (no entry points, no separate
    package). Serving hooks (render_page / get_client_js / send_static_file /
    format_build_error) are inlined into core's defaults; these providers
    contribute the ``[client]`` / ``[desktop]`` config schema, plugin metadata,
    and project templates. CLI commands and shadcn templates register separately
    via :func:`jaclang.cli.registry.register_feature_commands` and
    :func:`jaclang.project.template_registry.initialize_template_registry` so
    this path never imports the heavy client CLI or compiler surface.
    """
    try:
        from jaclang.runtimelib.client.desktop_plugin_config import (
            JacDesktopPluginConfig,
        )
        from jaclang.runtimelib.client.plugin_config import JacClientPluginConfig
    except Exception as exc:  # keep core usable if the framework fails to import
        warnings.warn(f"Built-in client framework unavailable: {exc}", stacklevel=2)
        return
    for _provider in (JacClientPluginConfig, JacDesktopPluginConfig):
        if not plugin_manager.is_registered(_provider):
            plugin_manager.register(_provider)


def _register_builtin_scale_provider(plugin_manager: object) -> None:
    """Register the built-in scale provider (serve / deploy / microservices).

    This shipped as the separate ``jac-scale`` plugin; it is now part of core
    and registers directly (no entry point, no separate package). All heavy
    third-party imports (fastapi/uvicorn/pymongo/...) are deferred into the
    hook bodies, so this registration never pulls the serve runtime closure at
    ``import jaclang`` time; those deps arrive in the project ``.jac/venv`` via
    the capability registry.

    Note: ``jaclang.scale.plugin`` historically self-registered ``JacScalePlugin``
    via its ``with entry`` block on import; registration is now explicit (here)
    so that merely importing the module does not mutate global plugin state.
    """
    try:
        from jaclang.scale.config.plugin_config import JacScalePluginConfig
        from jaclang.scale.plugin import JacScalePlugin
    except Exception as exc:  # keep core usable if scale fails to import
        warnings.warn(f"Built-in scale provider unavailable: {exc}", stacklevel=2)
        return
    for _provider in (JacScalePluginConfig, JacScalePlugin):
        if not plugin_manager.is_registered(_provider):
            plugin_manager.register(_provider)


def _register_builtin_mcp_provider(plugin_manager: object) -> None:
    """Register the built-in MCP server's config provider.

    This shipped as the separate ``jac-mcp`` plugin; it is now part of core and
    registers directly (no entry point, no separate package, and -- since the
    protocol is reimplemented on the standard library in ``jaclang.cli.mcp`` --
    no external ``mcp``/pydantic/starlette/uvicorn dependency). The ``jac mcp``
    command itself auto-registers when ``jaclang.cli.commands.mcp`` is imported
    during CLI init; registering the plugin class here contributes the
    ``[mcp]`` config schema and plugin metadata.
    """
    try:
        from jaclang.cli.mcp.plugin_config import JacMcpPluginConfig
    except Exception as exc:  # keep core usable if the MCP provider fails to import
        warnings.warn(f"Built-in MCP provider unavailable: {exc}", stacklevel=2)
        return
    if not plugin_manager.is_registered(JacMcpPluginConfig):
        plugin_manager.register(JacMcpPluginConfig)


def _register_builtin_byllm_provider(plugin_manager: object) -> None:
    """Register the built-in byLLM provider (the ``by llm()`` feature).

    This shipped as the separate ``jac-byllm`` plugin; it is now part of core
    and registers directly (no entry point, no separate package). All heavy
    third-party imports (litellm/openai/pydantic/pillow/loguru) are deferred
    behind ``jaclang.byllm._optdeps`` shims and a ``require_optional`` guard in
    ``Model.postinit``, so this registration never pulls the ``llm`` capability
    closure at ``import jaclang`` time; those deps arrive in the project
    ``.jac/venv`` via the capability registry when ``[byllm]`` is declared.
    """
    try:
        import jaclang.byllm.cli  # noqa: F401 — registers model command
        from jaclang.byllm.plugin_config import JacByllmPluginConfig
    except Exception as exc:  # keep core usable if byllm fails to import
        warnings.warn(f"Built-in byLLM provider unavailable: {exc}", stacklevel=2)
        return
    if not plugin_manager.is_registered(JacByllmPluginConfig):
        plugin_manager.register(JacByllmPluginConfig)


def _maybe_schedule_native_accel() -> None:
    """Schedule deferred native acceleration if autonative is enabled.

    Lives in the product tier because it pulls ``jaclang.project.config`` (a
    large subtree) which must not be loaded by a bare ``import jaclang``.
    """
    try:
        from jaclang.project.config import get_config as _get_jac_config

        _jac_cfg = _get_jac_config()
        if _jac_cfg and _jac_cfg.run.autonative:
            from jaclang.jac0core.native_accel import schedule_native_acceleration

            schedule_native_acceleration()
    except Exception:
        pass  # Config not available or acceleration failed -- continue normally
