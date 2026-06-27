"""Minimal plugin system for Jac.

Replaces the vendored pluggy library with a lightweight implementation
that supports only the features used by the Jac ecosystem.
"""

import inspect;
import importlib.metadata;
import from collections.abc { Callable }
import from typing { Any, TypeVar, cast }

glob _F = TypeVar('_F', bound=Callable[(..., object)]),
     _IMPL_ATTR = '_jac_hookimpl',
     _SPEC_ATTR = '_jac_hookspec',
     _HOOKABLE_ATTR = '_jac_hookable';

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

"""Marks an interface method as a plugin extension point (a hook).

Applied at the method's declaration in its domain class so hook-ness is
local and self-documenting. `build_plugin_hook_layer` reflects over the
runtime interface, collects every method carrying `_HOOKABLE_ATTR`, and
turns those (and only those) into dispatchable `plugin_manager` hooks --
everything else stays a plain inherited direct method. `firstresult` defaults
to True (a plugin override wins, core default falls through); set it False for
aggregating hooks where every plugin contributes (e.g. register_project_template).
"""
obj HookableMarker {
    def __call__(
        function: (_F | None) = None, *, firstresult: bool = True
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
    code = func?.__code__;
    if code is not None {
        nargs = code.co_argcount + code.co_kwonlyargcount;
        return tuple(code.co_varnames[:nargs]);
    }
    return None;
}

"""True when every parameter is positional-or-keyword or keyword-only, so a
real-signature wrapper can forward them by name safely. Params named `__jac*`
are rejected too: they would collide with the codegen'd internals."""
def _is_simple_sig(sig: inspect.Signature) -> bool {
    for p in sig.parameters.values() {
        if p.kind in (
            inspect.Parameter.VAR_POSITIONAL,
            inspect.Parameter.VAR_KEYWORD,
            inspect.Parameter.POSITIONAL_ONLY
        )
        or p.name.startswith('__jac') {
            return False;
        }
    }
    return True;
}

"""Codegen a real-signature facade method that calls one resolved hook impl
directly -- no HookCaller dispatch and no inspect at call time (Phase 2
devirtualization for single-impl hooks)."""
def _build_devirt(
    name: str,
    sig: inspect.Signature,
    impl_fn: Callable[(..., Any)],
    argnames: (tuple[(str, ...)] | None),
    is_coro: bool
) -> Callable[(..., Any)] {
    ns: dict[(str, Any)] = {'__jac_impl': impl_fn, '__jac_inspect': inspect};
    src_params = [];
    fwd = [];
    seen_kwonly = False;
    for (i, p) in enumerate(sig.parameters.values()) {
        if (p.kind == inspect.Parameter.KEYWORD_ONLY) and (not seen_kwonly) {
            src_params.append('*');
            seen_kwonly = True;
        }
        if p.default is inspect.Parameter.empty {
            src_params.append(p.name);
        } else {
            ns['__jac_d' + str(i)] = p.default;
            src_params.append(p.name + '=__jac_d' + str(i));
        }
        if (argnames is None) or (p.name in argnames) {
            fwd.append(p.name + '=' + p.name);
        }
    }
    kw = 'async def ' if is_coro else 'def ';
    lines = [kw + name + '(' + ', '.join(src_params) + '):'];
    if is_coro {
        lines.append('    __jac_result = __jac_impl(' + ', '.join(fwd) + ')');
        lines.append('    if __jac_inspect.iscoroutine(__jac_result):');
        lines.append('        return await __jac_result');
        lines.append('    return __jac_result');
    } else {
        lines.append('    return __jac_impl(' + ', '.join(fwd) + ')');
    }
    exec('\n'.join(lines) + '\n', ns);
    fn = ns[name];
    fn.__name__ = name;
    fn.__signature__ = sig;
    return cast(Callable[(..., Any)], fn);
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
        hook: HookRelay by postinit,
        _sealed: bool = False,
        _facade: (type | None) = None,
        _phase1: dict[(str, Callable[(..., Any)])] by postinit;

    def postinit {
        self._name2plugin = {};
        self._plugin2name = {};
        self._plugin_distinfo = [];
        self.hook = HookRelay();
        self._phase1 = {};
    }

    def seal(facade: type) -> None;
    def _specialize_hook(hook_name: str) -> None;
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
    return plugin?.__name__ or `type(plugin).__name__;
}

"""Thin wrapper around importlib.metadata.Distribution."""
obj _DistFacade {
    has _dist: importlib.metadata.Distribution;
    has project_name: str { getter; }
    has version: str { getter; }

    def __getattr__(attr: str) -> object;
}
