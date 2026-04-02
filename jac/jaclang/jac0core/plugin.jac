"""Minimal plugin system for Jac.

Replaces the vendored pluggy library with a lightweight implementation
that supports only the features used by the Jac ecosystem.
"""

import inspect;
import importlib.metadata;
import from collections.abc { Callable }
import from typing { Any, TypeVar }

glob _F = TypeVar('_F', bound=Callable[(..., object)]),
     _IMPL_ATTR = '_jac_hookimpl',
     _SPEC_ATTR = '_jac_hookspec';

"""Marks a function as a hook implementation."""
obj HookimplMarker {
    has project_name: str = '';

    def __call__(function: _F) -> _F;
}

"""Marks a function as a hook specification."""
obj HookspecMarker {
    has project_name: str = '';

    def __call__(
        function: (_F | None) = None, *, firstresult: bool = False
    ) -> (_F | Callable[([_F], _F)]);
}

"""Return the parameter names of func, or None if it accepts **kwargs."""
def _get_argnames(func: Callable[(..., Any)]) -> (tuple[(str, ...)] | None) {
    try {
        params = inspect.signature(func).parameters;
        for p in params.values() {
            if p.kind == inspect.Parameter.VAR_KEYWORD {
                return None;
            }
        }
        return tuple(
            p.name
            for p in params.values()
            if p.kind in (
                inspect.Parameter.POSITIONAL_OR_KEYWORD,
                inspect.Parameter.KEYWORD_ONLY
            )
        );
    } except (ValueError, TypeError) { }
    code = getattr(func, '__code__', None);
    if code is not None {
        nargs = code.co_argcount + code.co_kwonlyargcount;
        return tuple(code.co_varnames[:nargs]);
    }
    return None;
}

"""Represents a single hook implementation."""
obj HookImpl {
    has function: Callable[(..., Any)],
        plugin: object,
        plugin_name: str,
        argnames: (tuple[(str, ...)] | None) = None;

    def __repr__ -> str;
}

"""Manages implementations for a single hook and dispatches calls."""
obj HookCaller {
    has name: str,
        _hookimpls: list[HookImpl] by postinit,
        _firstresult: bool = False;

    def postinit {
        self._hookimpls = [];
    }

    def _add_hookimpl(hi: HookImpl) -> None;
    def _remove_plugin(plugin: object) -> None;
    def get_hookimpls -> list[HookImpl];
    def _call_impl(hi: HookImpl, kwargs: dict[(str, object)]) -> object;
    def __call__(**kwargs: object) -> object;
    def __repr__ -> str;
}

"""Namespace object for plugin_manager.hook.<name> access."""
class HookRelay {}

"""Registers plugins, manages hook specs, and dispatches hook calls."""
obj PluginManager {
    has project_name: str = '',
        _name2plugin: dict[(str, object)] by postinit,
        _plugin2name: dict[(int, str)] by postinit,
        _plugin_distinfo: list[tuple[(object, Any)]] by postinit,
        hook: HookRelay by postinit;

    def postinit {
        self._name2plugin = {};
        self._plugin2name = {};
        self._plugin_distinfo = [];
        self.hook = HookRelay();
    }

    def register(plugin: object, name: (str | None) = None) -> (str | None);
    def unregister(
        plugin: (object | None) = None, name: (str | None) = None
    ) -> (object | None);

    def is_registered(plugin: object) -> bool;
    def add_hookspecs(spec_class: type) -> None;
    def list_name_plugin -> list[tuple[(str, object)]];
    def list_plugin_distinfo -> list[tuple[(object, Any)]];
    def load_setuptools_entrypoints(group: str) -> int;
}

def _canonical_name(plugin: object) -> str {
    return getattr(plugin, '__name__', None) or `type(plugin).__name__;
}

"""Thin wrapper around importlib.metadata.Distribution."""
obj _DistFacade {
    has _dist: importlib.metadata.Distribution;

    @property
    def project_name -> str;

    @property
    def version -> str;

    def __getattr__(attr: str) -> object;
}
