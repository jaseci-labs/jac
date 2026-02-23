"""Minimal plugin system for Jac.

Replaces the vendored pluggy library with a lightweight implementation
that supports only the features used by the Jac ecosystem.
"""

from __future__ import annotations

import importlib.metadata
import inspect
from collections.abc import Callable
from typing import Any, TypeVar

_F = TypeVar("_F", bound=Callable[..., object])

_IMPL_ATTR = "_jac_hookimpl"
_SPEC_ATTR = "_jac_hookspec"


class HookimplMarker:
    """Marks a function as a hook implementation.

    Usage::

        hookimpl = HookimplMarker("jac")

        @hookimpl
        def some_hook(arg):
            ...
    """

    def __init__(self, project_name: str = "") -> None:
        self.project_name = project_name

    def __call__(self, function: _F) -> _F:
        setattr(function, _IMPL_ATTR, True)
        return function


class HookspecMarker:
    """Marks a function as a hook specification.

    Usage::

        hookspec = HookspecMarker("jac")

        @hookspec(firstresult=True)
        def some_hook(arg):
            ...
    """

    def __init__(self, project_name: str = "") -> None:
        self.project_name = project_name

    def __call__(
        self,
        function: _F | None = None,
        *,
        firstresult: bool = False,
    ) -> _F | Callable[[_F], _F]:
        def mark(func: _F) -> _F:
            setattr(func, _SPEC_ATTR, {"firstresult": firstresult})
            return func

        if function is not None:
            return mark(function)
        return mark


def _get_argnames(func: Callable[..., Any]) -> tuple[str, ...] | None:
    """Return the parameter names of *func*, or *None* if it accepts **kwargs."""
    try:
        params = inspect.signature(func).parameters
        for p in params.values():
            if p.kind == inspect.Parameter.VAR_KEYWORD:
                return None  # accepts **kwargs — pass everything
        return tuple(
            p.name
            for p in params.values()
            if p.kind
            in (
                inspect.Parameter.POSITIONAL_OR_KEYWORD,
                inspect.Parameter.KEYWORD_ONLY,
            )
        )
    except (ValueError, TypeError):
        pass
    # Fallback: use the code object directly (works for Jac-compiled functions).
    code = getattr(func, "__code__", None)
    if code is not None:
        nargs = code.co_argcount + code.co_kwonlyargcount
        return tuple(code.co_varnames[:nargs])
    return None  # unknown — pass everything through


class HookImpl:
    """Represents a single hook implementation."""

    __slots__ = ("function", "plugin", "plugin_name", "argnames")

    def __init__(
        self, function: Callable[..., Any], plugin: object, plugin_name: str
    ) -> None:
        self.function = function
        self.plugin = plugin
        self.plugin_name = plugin_name
        self.argnames = _get_argnames(function)

    def __repr__(self) -> str:
        return f"<HookImpl plugin_name={self.plugin_name!r}>"


class HookCaller:
    """Manages implementations for a single hook and dispatches calls."""

    __slots__ = ("name", "_hookimpls", "_firstresult")

    def __init__(self, name: str, firstresult: bool = False) -> None:
        self.name = name
        self._hookimpls: list[HookImpl] = []
        self._firstresult = firstresult

    def _add_hookimpl(self, impl: HookImpl) -> None:
        self._hookimpls.append(impl)

    def _remove_plugin(self, plugin: object) -> None:
        self._hookimpls = [h for h in self._hookimpls if h.plugin is not plugin]

    def get_hookimpls(self) -> list[HookImpl]:
        return list(self._hookimpls)

    @staticmethod
    def _call_impl(impl: HookImpl, kwargs: dict[str, object]) -> object:
        if impl.argnames is None:
            return impl.function(**kwargs)
        return impl.function(
            **{name: kwargs[name] for name in impl.argnames if name in kwargs}
        )

    def __call__(self, **kwargs: object) -> object:
        # Iterate in reverse so the last-registered plugin wins.
        if self._firstresult:
            for impl in reversed(self._hookimpls):
                result = self._call_impl(impl, kwargs)
                if result is not None:
                    return result
            return None

        results: list[Any] = []
        for impl in reversed(self._hookimpls):
            result = self._call_impl(impl, kwargs)
            if result is not None:
                results.append(result)
        return results

    def __repr__(self) -> str:
        return f"<HookCaller {self.name!r}>"


class HookRelay:
    """Namespace object for ``plugin_manager.hook.<name>`` access."""


class PluginManager:
    """Registers plugins, manages hook specs, and dispatches hook calls."""

    def __init__(self, project_name: str = "") -> None:
        self.project_name = project_name
        self._name2plugin: dict[str, object] = {}
        self._plugin2name: dict[int, str] = {}
        self._plugin_distinfo: list[tuple[object, Any]] = []
        self.hook = HookRelay()

    # ------------------------------------------------------------------
    # Registration
    # ------------------------------------------------------------------

    def register(self, plugin: object, name: str | None = None) -> str | None:
        plugin_name = name or _canonical_name(plugin)

        if id(plugin) in self._plugin2name:
            return None  # already registered

        self._name2plugin[plugin_name] = plugin
        self._plugin2name[id(plugin)] = plugin_name

        # Walk the MRO __dict__ entries directly to avoid triggering
        # descriptor __get__ (which can emit DeprecationWarning for
        # @classmethod in Python 3.12+).
        seen: set[str] = set()
        for klass in inspect.getmro(
            type(plugin) if not isinstance(plugin, type) else plugin
        ):
            for attr_name, raw in vars(klass).items():
                if attr_name in seen:
                    continue
                seen.add(attr_name)
                # Unwrap classmethod / staticmethod descriptors.
                func = (
                    raw.__func__
                    if isinstance(raw, (classmethod, staticmethod))
                    else raw
                )
                if not callable(func):
                    continue
                if not getattr(func, _IMPL_ATTR, False):
                    continue
                # Now resolve through normal attribute access for the bound method.
                method = getattr(plugin, attr_name, None)
                if method is None:
                    continue

                impl = HookImpl(function=method, plugin=plugin, plugin_name=plugin_name)

                hook: HookCaller | None = getattr(self.hook, attr_name, None)
                if hook is None:
                    hook = HookCaller(attr_name, firstresult=False)
                    setattr(self.hook, attr_name, hook)
                hook._add_hookimpl(impl)

        return plugin_name

    def unregister(
        self,
        plugin: object | None = None,
        name: str | None = None,
    ) -> object | None:
        if plugin is None and name is not None:
            plugin = self._name2plugin.get(name)
        if plugin is None:
            return None

        plugin_name = self._plugin2name.pop(id(plugin), None)
        if plugin_name is not None:
            self._name2plugin.pop(plugin_name, None)
        if name is not None and name != plugin_name:
            self._name2plugin.pop(name, None)

        for attr_name in list(vars(self.hook)):
            hook = getattr(self.hook, attr_name, None)
            if isinstance(hook, HookCaller):
                hook._remove_plugin(plugin)

        return plugin

    def is_registered(self, plugin: object) -> bool:
        return id(plugin) in self._plugin2name

    # ------------------------------------------------------------------
    # Hook specifications
    # ------------------------------------------------------------------

    def add_hookspecs(self, spec_class: type) -> None:
        for attr_name in dir(spec_class):
            method = getattr(spec_class, attr_name, None)
            if method is None:
                continue
            spec_opts = getattr(method, _SPEC_ATTR, None)
            if spec_opts is None:
                continue

            firstresult = spec_opts.get("firstresult", False)
            hook: HookCaller | None = getattr(self.hook, attr_name, None)
            if hook is None:
                hook = HookCaller(attr_name, firstresult=firstresult)
                setattr(self.hook, attr_name, hook)
            else:
                hook._firstresult = firstresult

    # ------------------------------------------------------------------
    # Introspection
    # ------------------------------------------------------------------

    def list_name_plugin(self) -> list[tuple[str, object]]:
        return list(self._name2plugin.items())

    def list_plugin_distinfo(self) -> list[tuple[object, Any]]:
        return list(self._plugin_distinfo)

    # ------------------------------------------------------------------
    # Entry-point loading
    # ------------------------------------------------------------------

    def load_setuptools_entrypoints(self, group: str) -> int:
        count = 0
        for dist in importlib.metadata.distributions():
            for ep in dist.entry_points:
                if ep.group != group:
                    continue
                if ep.name in self._name2plugin:
                    continue
                try:
                    plugin = ep.load()
                except Exception:
                    continue
                self.register(plugin, name=ep.name)
                self._plugin_distinfo.append((plugin, _DistFacade(dist)))
                count += 1
        return count


def _canonical_name(plugin: object) -> str:
    return getattr(plugin, "__name__", None) or type(plugin).__name__


class _DistFacade:
    """Thin wrapper around importlib.metadata.Distribution."""

    def __init__(self, dist: importlib.metadata.Distribution) -> None:
        self._dist = dist

    @property
    def project_name(self) -> str:
        return self._dist.metadata["Name"]

    @property
    def version(self) -> str:
        return self._dist.metadata.get("Version", "0.0.0")

    def __getattr__(self, attr: str) -> object:
        return getattr(self._dist, attr)
