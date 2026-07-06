"""The Jac Programming Language."""

import sys

from jaclang.meta_importer import JacMetaImporter  # noqa: E402

# Register JacMetaImporter BEFORE loading plugins, so .jac modules can be imported
if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path):
    sys.meta_path.insert(0, JacMetaImporter())

# Import compiler first to ensure generated parsers exist before jac0core.parser is loaded
# Backwards-compatible import path for older plugins/tests.
# Prefer `jaclang.jac0core.runtime` going forward.
import jaclang.jac0core.runtime as _runtime_mod  # noqa: E402
from jaclang import compiler as _compiler  # noqa: E402, F401
from jaclang.jac0core.helpers import (  # noqa: E402
    get_disabled_plugins,
    load_plugins_with_disabling,
)
from jaclang.jac0core.runtime import (  # noqa: E402
    JacRuntime,
    JacRuntimeImpl,
    JacRuntimeInterface,
    plugin_manager,
)

sys.modules.setdefault("jaclang.runtimelib.runtime", _runtime_mod)

plugin_manager.register(JacRuntimeImpl)

# Put the current project's .jac/venv on sys.path BEFORE enumerating plugins, so
# per-project plugins (jac install [-e] <pkg>) are discovered. In the single
# binary this already ran via sitecustomize during interpreter startup; this call
# is the library-use fallback (plain `import jaclang` with no sitecustomize). The
# helper is idempotent and uses addsitedir, so editable .pth links are processed.
with __import__("contextlib").suppress(Exception):
    import _jac_finder as _jf

    _jf.add_project_venv_to_path()

# Load external plugins with disabling support
# Disabling can be configured via JAC_DISABLED_PLUGINS env var or jac.toml [plugins].disabled
# Use "*" to disable all external plugins, "package:*" for all from a package,
# or "package:plugin" for specific plugins
_disabled_list = get_disabled_plugins()
# Always go through load_plugins_with_disabling so plugin-load failures
# are surfaced as warnings (instead of silently swallowed by pluggy's
# load_setuptools_entrypoints). The disable list may be empty.
load_plugins_with_disabling(plugin_manager, _disabled_list)


def _register_builtin_client_providers() -> None:
    """Register the built-in client/desktop framework hook providers.

    These shipped as the separate ``jac-client`` / ``jac-desktop`` plugins; they are
    now part of core and register directly (no entry points, no separate package).
    Serving hooks (render_page / get_client_js / send_static_file / format_build_error)
    are inlined into core's defaults; these providers contribute the ``[plugins.client]``
    / ``[plugins.desktop]`` config schema, the npm dependency type, the project
    templates (fullstack/client/mobile/desktop), plugin metadata, and the client CLI
    commands (``build`` / ``setup`` / ``start`` + ``--npm`` / ``--cl``).
    """
    try:
        from jaclang.runtimelib.client.cli import JacClientCmd
        from jaclang.runtimelib.client.desktop_plugin_config import (
            JacDesktopPluginConfig,
        )
        from jaclang.runtimelib.client.plugin_config import JacClientPluginConfig
    except Exception as exc:  # keep core usable if the framework fails to import
        import warnings

        warnings.warn(f"Built-in client framework unavailable: {exc}", stacklevel=2)
        return
    for _provider in (JacClientPluginConfig, JacDesktopPluginConfig, JacClientCmd):
        if not plugin_manager.is_registered(_provider):
            plugin_manager.register(_provider)


_register_builtin_client_providers()


def _register_builtin_shadcn_provider() -> None:
    """Register the built-in shadcn/ui CLI provider.

    This shipped as the ``shadcn`` entry point of the separate ``jac-super``
    plugin; it is now part of core and registers directly (no entry point, no
    separate package). Importing the module also registers the ``jac retheme``
    command (via its ``@registry.command`` decorator); registering the plugin
    class wires its ``create_cmd`` / ``register_project_template`` hooks, which
    add the ``--shadcn`` flags and the ``jac-shadcn`` project template.
    """
    try:
        from jaclang.cli.shadcn.plugin import JacShadcnPlugin
    except Exception as exc:  # keep core usable if shadcn fails to import
        import warnings

        warnings.warn(f"Built-in shadcn provider unavailable: {exc}", stacklevel=2)
        return
    if not plugin_manager.is_registered(JacShadcnPlugin):
        plugin_manager.register(JacShadcnPlugin)


_register_builtin_shadcn_provider()


def _register_builtin_scale_provider() -> None:
    """Register the built-in scale provider (serve / deploy / microservices).

    This shipped as the separate ``jac-scale`` plugin; it is now part of core and
    registers directly (no entry point, no separate package). Importing
    ``jaclang.scale.plugin`` runs its ``with entry`` block, which registers the
    ``JacScalePlugin`` hook implementations; we additionally register the scale
    CLI command provider (``JacCmd`` -> ``--scale`` / ``destroy`` / ``status`` /
    ``scale``) and the ``[scale.*]`` config-schema provider. All heavy third-party
    imports (fastapi/uvicorn/pymongo/...) are deferred into the hook bodies, so this
    registration never pulls the serve runtime closure at ``import jaclang`` time;
    those deps arrive in the project ``.jac/venv`` via the capability registry.
    """
    try:
        from jaclang.scale.config.plugin_config import JacScalePluginConfig
        from jaclang.scale.plugin import JacCmd
    except Exception as exc:  # keep core usable if scale fails to import
        import warnings

        warnings.warn(f"Built-in scale provider unavailable: {exc}", stacklevel=2)
        return
    for _provider in (JacCmd, JacScalePluginConfig):
        if not plugin_manager.is_registered(_provider):
            plugin_manager.register(_provider)


_register_builtin_scale_provider()


def _register_builtin_mcp_provider() -> None:
    """Register the built-in MCP server's config provider.

    This shipped as the separate ``jac-mcp`` plugin; it is now part of core and
    registers directly (no entry point, no separate package, and -- since the
    protocol is reimplemented on the standard library in ``jaclang.cli.mcp`` --
    no external ``mcp``/pydantic/starlette/uvicorn dependency). The ``jac mcp``
    command itself auto-registers when ``jaclang.cli.commands.mcp`` is imported
    during CLI init; registering the plugin class here contributes the
    ``[plugins.mcp]`` config schema and plugin metadata.
    """
    try:
        from jaclang.cli.mcp.plugin_config import JacMcpPluginConfig
    except Exception as exc:  # keep core usable if the MCP provider fails to import
        import warnings

        warnings.warn(f"Built-in MCP provider unavailable: {exc}", stacklevel=2)
        return
    if not plugin_manager.is_registered(JacMcpPluginConfig):
        plugin_manager.register(JacMcpPluginConfig)


_register_builtin_mcp_provider()


def _register_builtin_byllm_provider() -> None:
    """Register the built-in byLLM provider (the ``by llm()`` feature).

    This shipped as the separate ``jac-byllm`` plugin; it is now part of core and
    registers directly (no entry point, no separate package). All heavy
    third-party imports (litellm/openai/pydantic/pillow/loguru) are deferred behind
    ``jaclang.byllm._optdeps`` shims and a ``require_optional`` guard in
    ``Model.postinit``, so this registration never pulls the ``llm`` capability
    closure at ``import jaclang`` time; those deps arrive in the project
    ``.jac/venv`` via the capability registry when ``[plugins.byllm]`` is declared.
    """
    try:
        from jaclang.byllm.cli import JacCmd
        from jaclang.byllm.plugin import JacRuntime as JacByllmRuntime
        from jaclang.byllm.plugin_config import JacByllmPluginConfig
    except Exception as exc:  # keep core usable if byllm fails to import
        import warnings

        warnings.warn(f"Built-in byLLM provider unavailable: {exc}", stacklevel=2)
        return
    for _provider in (JacByllmRuntime, JacCmd, JacByllmPluginConfig):
        if not plugin_manager.is_registered(_provider):
            plugin_manager.register(_provider)


_register_builtin_byllm_provider()

# Schedule deferred native acceleration if autonative is enabled in jac.toml
try:
    from jaclang.project.config import get_config as _get_jac_config

    _jac_cfg = _get_jac_config()
    if _jac_cfg and _jac_cfg.run.autonative:
        from jaclang.jac0core.native_accel import schedule_native_acceleration

        schedule_native_acceleration()
except Exception:
    pass  # Config not available or acceleration failed — continue normally

__all__ = ["JacRuntimeInterface", "JacRuntime"]
