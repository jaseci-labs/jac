"""Hook-aware lazy plugin loading with plugin self-declaration.

Plugins declare their hooks in pyproject.toml:
    [project.entry-points."jac.hooks"]
    byllm = ["get_mtir", "call_llm"]

This allows:
1. Zero imports during plugin discovery
2. Loading only plugins that implement the hook being called
3. No central registry to maintain - plugins self-declare
4. Fallback for plugins that don't declare (AST parsing or conservative loading)
"""

from __future__ import annotations

import ast
import sys
from importlib.metadata import EntryPoint, entry_points
from logging import getLogger
from pathlib import Path
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    import pluggy

logger = getLogger(__name__)


def discover_hooks_from_ast(module_path: str) -> set[str]:
    """Discover @hookimpl decorators by parsing source (no import).

    Args:
        module_path: Module path like "byllm.plugin:JacMachine"

    Returns:
        Set of hook method names
    """
    hooks = set()

    try:
        # Parse module:class format
        parts = module_path.split(":")
        if len(parts) != 2:
            return hooks

        module_name, class_name = parts
        module_parts = module_name.split(".")

        # Find source file in sys.path
        source_file = None
        for path_entry in sys.path:
            base = Path(path_entry)
            # Try module.py
            candidate = base.joinpath(*module_parts).with_suffix(".py")
            if candidate.exists():
                source_file = candidate
                break
            # Try package/__init__.py
            candidate = base.joinpath(*module_parts) / "__init__.py"
            if candidate.exists():
                source_file = candidate
                break

        if not source_file:
            return hooks

        # Parse AST
        with open(source_file) as f:
            tree = ast.parse(f.read())

        # Find target class
        target_class = None
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef) and node.name == class_name:
                target_class = node
                break

        if not target_class:
            return hooks

        # Find @hookimpl decorated methods
        for item in target_class.body:
            if isinstance(item, ast.FunctionDef):
                for decorator in item.decorator_list:
                    decorator_name = None
                    if isinstance(decorator, ast.Name):
                        decorator_name = decorator.id
                    elif isinstance(decorator, ast.Attribute):
                        decorator_name = decorator.attr

                    if decorator_name == "hookimpl":
                        hooks.add(item.name)
                        break

        logger.debug(f"AST discovered hooks in {module_path}: {hooks}")

    except Exception as e:
        logger.debug(f"AST parsing failed for {module_path}: {e}")

    return hooks


class HookAwareLazyHookCaller:
    """Proxy for hook callers that triggers plugin loading."""

    def __init__(
        self,
        hook_name: str,
        real_hook_caller: Any,
        lazy_manager: HookAwareLazyPluginManager,
    ) -> None:
        """Initialize lazy hook caller."""
        self._hook_name = hook_name
        self._real_hook_caller = real_hook_caller
        self._lazy_manager = lazy_manager

    def __call__(self, **kwargs: Any) -> Any:
        """Call hook, loading only relevant plugins first."""
        self._lazy_manager._ensure_loaded_for_hook(self._hook_name)
        return self._real_hook_caller(**kwargs)

    def __getattr__(self, name: str) -> Any:
        """Proxy to real hook caller."""
        return getattr(self._real_hook_caller, name)


class HookAwareLazyHookRelay:
    """Proxy for hook relay that returns lazy hook callers."""

    def __init__(
        self, real_hook_relay: Any, lazy_manager: HookAwareLazyPluginManager
    ) -> None:
        """Initialize lazy hook relay."""
        self._real_hook_relay = real_hook_relay
        self._lazy_manager = lazy_manager

    def __getattr__(self, name: str) -> HookAwareLazyHookCaller:
        """Get hook caller wrapped in lazy loading."""
        real_caller = getattr(self._real_hook_relay, name)
        return HookAwareLazyHookCaller(name, real_caller, self._lazy_manager)


class HookAwareLazyPluginManager:
    """Lazy plugin manager that loads plugins based on hook usage.

    Plugins declare their hooks via entry points:
        [project.entry-points."jac.hooks"]
        plugin_name = ["hook1", "hook2"]

    Plugins are only loaded when a hook they implement is called.
    """

    def __init__(self, pm: pluggy.PluginManager) -> None:
        """Initialize with existing PluginManager."""
        self._pm = pm
        self._lazy_plugins: dict[str, EntryPoint] = {}
        self._loaded_plugins: set[str] = set()
        self._hook_to_plugins: dict[str, set[str]] = {}
        self._undeclared_plugins: set[str] = set()
        self._hooks_discovered = False

    def load_setuptools_entrypoints_lazy(self, group: str) -> int:
        """Scan plugin entry points without importing them.

        Args:
            group: Entry point group (e.g., "jac")

        Returns:
            Number of plugins found
        """
        # Get plugin entry points
        eps = entry_points(group=group)
        count = 0
        for ep in eps:
            self._lazy_plugins[ep.name] = ep
            count += 1

        logger.debug(f"Found {count} plugins in group '{group}'")
        return count

    def _discover_hooks(self) -> None:
        """Discover which hooks each plugin implements (without importing)."""
        if self._hooks_discovered:
            return

        # Try to get hook declarations from entry points
        # Plugins should declare: [project.entry-points."jac.hooks"]
        hook_group = "jac.hooks"
        try:
            hook_eps = entry_points(group=hook_group)
            declared_plugins = set()

            for ep in hook_eps:
                plugin_name = ep.name
                declared_plugins.add(plugin_name)

                try:
                    # Load the hook list (should be just a list, not code)
                    # The entry point value might be a list literal or callable
                    hooks = ep.load()
                    if not isinstance(hooks, (list, set, tuple)):
                        logger.warning(
                            f"Plugin '{plugin_name}' hook declaration is not a list: {hooks}"
                        )
                        continue

                    # Map hooks to this plugin
                    for hook in hooks:
                        if hook not in self._hook_to_plugins:
                            self._hook_to_plugins[hook] = set()
                        self._hook_to_plugins[hook].add(plugin_name)

                    logger.debug(
                        f"Plugin '{plugin_name}' declares hooks: {set(hooks)}"
                    )

                except Exception as e:
                    logger.warning(
                        f"Failed to load hook declaration for '{plugin_name}': {e}"
                    )

        except Exception as e:
            logger.debug(f"No hook declarations found in group '{hook_group}': {e}")
            declared_plugins = set()

        # For plugins without declarations, try AST discovery
        undeclared = set(self._lazy_plugins.keys()) - declared_plugins

        for plugin_name in undeclared:
            ep = self._lazy_plugins[plugin_name]
            hooks = discover_hooks_from_ast(ep.value)

            if hooks:
                # Successfully discovered via AST
                for hook in hooks:
                    if hook not in self._hook_to_plugins:
                        self._hook_to_plugins[hook] = set()
                    self._hook_to_plugins[hook].add(plugin_name)
                logger.debug(
                    f"Plugin '{plugin_name}' hooks discovered via AST: {hooks}"
                )
            else:
                # Couldn't discover - mark for conservative loading
                self._undeclared_plugins.add(plugin_name)
                logger.debug(
                    f"Plugin '{plugin_name}' hooks unknown - will load conservatively"
                )

        self._hooks_discovered = True

    def _ensure_loaded_for_hook(self, hook_name: str) -> None:
        """Load only plugins that implement this hook.

        Args:
            hook_name: Name of hook being called
        """
        # Discover hooks on first use
        if not self._hooks_discovered:
            self._discover_hooks()

        # Load plugins that declared this hook
        plugins_for_hook = self._hook_to_plugins.get(hook_name, set())
        for plugin_name in plugins_for_hook:
            if plugin_name not in self._loaded_plugins:
                self._load_plugin(plugin_name)

        # Also load undeclared plugins (conservative fallback)
        # These are plugins where we couldn't determine hooks
        for plugin_name in self._undeclared_plugins:
            if plugin_name not in self._loaded_plugins:
                self._load_plugin(plugin_name)
                logger.debug(
                    f"Loaded undeclared plugin '{plugin_name}' conservatively"
                )

    def _load_plugin(self, plugin_name: str) -> None:
        """Load and register a specific plugin.

        Args:
            plugin_name: Name of plugin to load
        """
        if plugin_name in self._loaded_plugins:
            return

        if plugin_name not in self._lazy_plugins:
            logger.warning(f"Cannot load unknown plugin: {plugin_name}")
            return

        ep = self._lazy_plugins[plugin_name]
        try:
            # NOW we import the plugin
            plugin_obj = ep.load()
            self._pm.register(plugin_obj)
            self._loaded_plugins.add(plugin_name)
            logger.info(f"Loaded plugin '{plugin_name}'")
        except Exception as e:
            logger.error(f"Failed to load plugin '{plugin_name}': {e}")

    def ensure_all_loaded(self) -> None:
        """Explicitly load all plugins (for testing/debugging)."""
        for plugin_name in self._lazy_plugins:
            if plugin_name not in self._loaded_plugins:
                self._load_plugin(plugin_name)

    def register(self, plugin: Any, name: str | None = None) -> str | None:
        """Register a plugin directly (non-lazy)."""
        return self._pm.register(plugin, name)

    def add_hookspecs(self, module_or_class: Any) -> None:
        """Add hook specifications."""
        self._pm.add_hookspecs(module_or_class)

    @property
    def hook(self) -> HookAwareLazyHookRelay:
        """Get hook relay with lazy loading."""
        return HookAwareLazyHookRelay(self._pm.hook, self)

    def __getattr__(self, name: str) -> Any:
        """Proxy to real PluginManager."""
        return getattr(self._pm, name)


def create_lazy_plugin_manager(project_name: str) -> HookAwareLazyPluginManager:
    """Create a hook-aware lazy plugin manager.

    Args:
        project_name: Plugin project name (e.g., "jac")

    Returns:
        HookAwareLazyPluginManager wrapping a PluginManager
    """
    import pluggy

    pm = pluggy.PluginManager(project_name)
    return HookAwareLazyPluginManager(pm)
