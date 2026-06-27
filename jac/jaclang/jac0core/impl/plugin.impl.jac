"""Implementation for plugin system."""

impl HookimplMarker.__call__(function: _F) -> _F {
    setattr(function, _IMPL_ATTR, True);
    return function;
}

impl HookspecMarker.__call__(
    function: (_F | None) = None, *, firstresult: bool = False
) -> (_F | Callable[([_F], _F)]) {
    def mark(func: _F) -> _F {
        setattr(func, _SPEC_ATTR, {'firstresult': firstresult});
        return func;
    }
    if function is not None {
        return mark(function);
    }
    return mark;
}

impl HookableMarker.__call__(
    function: (_F | None) = None, *, firstresult: bool = True
) -> (_F | Callable[([_F], _F)]) {
    def mark(func: _F) -> _F {
        setattr(func, _HOOKABLE_ATTR, {'firstresult': firstresult});
        return func;
    }
    if function is not None {
        return mark(function);
    }
    return mark;
}

impl HookImpl.__repr__ -> str {
    return f"<HookImpl plugin_name={self.plugin_name!r}>";
}

impl HookCaller._add_hookimpl(hi: HookImpl) -> None {
    self._hookimpls.append(hi);
}

impl HookCaller._remove_plugin(plugin: object) -> None {
    self._hookimpls = [
        h
        for h in self._hookimpls
        if h.plugin is not plugin
    ];
}

impl HookCaller.get_hookimpls -> list[HookImpl] {
    return `list(self._hookimpls);
}

impl HookCaller._call_impl(hi: HookImpl, kwargs: dict[(str, object)]) -> object {
    if hi.argnames is None {
        return hi.function(**kwargs);
    }
    return hi.function(
        **{
            name: kwargs[name]
            for name in hi.argnames
            if name in kwargs
        }
    );
}

impl HookCaller.__call__(**kwargs: object) -> object {
    if self._firstresult {
        for hi in reversed(self._hookimpls) {
            result = self._call_impl(hi, kwargs);
            if result is not None {
                return result;
            }
        }
        return None;
    }
    results: list[any] = [];
    for hi in reversed(self._hookimpls) {
        result = self._call_impl(hi, kwargs);
        if result is not None {
            results.append(result);
        }
    }
    return results;
}

impl HookCaller.__repr__ -> str {
    return f"<HookCaller {self.name!r}>";
}

"""Freeze the resolved hook table: replace single-impl, simple-signature
facade methods with direct-call specializations. Safe to call before plugins
load -- register/unregister re-specialize affected hooks afterward."""
impl PluginManager.seal(facade: type) -> None {
    if self._sealed {
        return;
    }
    import os;
    # Ablation flag: JAC_HOOK_SEAL=0 keeps hooks on the Phase-1 dispatcher
    # (Phase-2 devirtualization disabled). Marked sealed so we skip re-checking.
    if os.environ.get('JAC_HOOK_SEAL', '1').strip().lower() in (
        '0',
        'false',
        'no',
        'off'
    ) {
        self._sealed = True;
        return;
    }
    self._facade = facade;
    for hook_name in `list(vars(self.hook).keys()) {
        m = getattr(facade, hook_name, None);
        if (m is not None) and callable(m) {
            self._phase1[hook_name] = m;
        }
    }
    self._sealed = True;
    for hook_name in `list(self._phase1.keys()) {
        self._specialize_hook(hook_name);
    }
}

"""(Re)install the fastest correct facade method for one hook: a direct-call
devirtualization when exactly one simple-signature impl is registered, else
the Phase-1 dynamic dispatcher captured at seal time."""
impl PluginManager._specialize_hook(hook_name: str) -> None {
    if (not self._sealed) or (self._facade is None) {
        return;
    }
    base = self._phase1.get(hook_name);
    if base is None {
        base = getattr(self._facade, hook_name, None);
        if (base is None) or (not callable(base)) {
            return;
        }
        self._phase1[hook_name] = base;
    }
    hook = getattr(self.hook, hook_name, None);
    impls = hook.get_hookimpls() if hook is not None else [];
    sig = inspect.signature(base);
    # non-firstresult hooks return a list; a direct call would change that
    is_firstresult = (hook is not None) and hook._firstresult;
    if (len(impls) == 1) and is_firstresult and _is_simple_sig(sig) {
        hi = impls[0];
        setattr(
            self._facade,
            hook_name,
            _build_devirt(
                hook_name,
                sig,
                hi.function,
                hi.argnames,
                inspect.iscoroutinefunction(base)
            )
        );
    } else {
        setattr(self._facade, hook_name, base);
    }
}

impl PluginManager.register(plugin: object, name: (str | None) = None) -> (str | None) {
    plugin_name = name or _canonical_name(plugin);
    if id(plugin) in self._plugin2name {
        return None;
    }
    self._name2plugin[plugin_name] = plugin;
    self._plugin2name[id(plugin)] = plugin_name;
    seen: set[str] = `set();
    touched: list[str] = [];
    for klass in inspect.getmro(
        `type(plugin) if not isinstance(plugin, type) else plugin
    ) {
        for (attr_name, raw) in vars(klass).items() {
            if attr_name in seen {
                continue;
            }
            seen.add(attr_name);
            func = (
                raw.__func__ if isinstance(raw, (classmethod, staticmethod)) else raw
            );
            if not callable(func) {
                continue;
            }
            if not getattr(func, _IMPL_ATTR, False) {
                continue;
            }
            method = getattr(plugin, attr_name, None);
            if method is None {
                continue;
            }

            hi = HookImpl(
                function=method,
                plugin=plugin,
                plugin_name=plugin_name,
                argnames=_get_argnames(method)
            );

            hook: (HookCaller | None) = getattr(self.hook, attr_name, None);
            if hook is None {
                hook = HookCaller(attr_name, _firstresult=False);
                setattr(self.hook, attr_name, hook);
            }
            hook._add_hookimpl(hi);
            touched.append(attr_name);
        }
    }
    if self._sealed {
        for an in touched {
            self._specialize_hook(an);
        }
    }
    return plugin_name;
}

impl PluginManager.unregister(
    plugin: (object | None) = None, name: (str | None) = None
) -> (object | None) {
    if plugin is None and name is not None {
        plugin = self._name2plugin.get(name);
    }
    if plugin is None {
        return None;
    }
    plugin_name = self._plugin2name.pop(id(plugin), None);
    if plugin_name is not None {
        self._name2plugin.pop(plugin_name, None);
    }
    if name is not None and name != plugin_name {
        self._name2plugin.pop(name, None);
    }
    # NOTE: we deliberately do NOT re-specialize on unregister. Devirtualized
    # hooks are core-only (single-impl); `without_plugins` only unregisters
    # *external* plugins, so it never touches them. Multi-impl hooks stay on
    # the dynamic Phase-1 dispatcher, which correctly follows the live impl
    # set as plugins drop out. Re-specializing here would transiently
    # devirtualize a multi-impl hook down to its core stub mid-`without_plugins`.
    for attr_name in `list(vars(self.hook)) {
        hook = getattr(self.hook, attr_name, None);
        if isinstance(hook, HookCaller) {
            hook._remove_plugin(plugin);
        }
    }
    return plugin;
}

impl PluginManager.is_registered(plugin: object) -> bool {
    return id(plugin) in self._plugin2name;
}

impl PluginManager.add_hookspecs(spec_class: type) -> None {
    for attr_name in dir(spec_class) {
        method = getattr(spec_class, attr_name, None);
        if method is None {
            continue;
        }
        spec_opts = getattr(method, _SPEC_ATTR, None);
        if spec_opts is None {
            continue;
        }

        firstresult = spec_opts.get('firstresult', False);
        hook: (HookCaller | None) = getattr(self.hook, attr_name, None);
        if hook is None {
            hook = HookCaller(attr_name, _firstresult=firstresult);
            setattr(self.hook, attr_name, hook);
        } else {
            hook._firstresult = firstresult;
        }
    }
}

impl PluginManager.list_name_plugin -> list[tuple[(str, object)]] {
    return `list(self._name2plugin.items());
}

impl PluginManager.list_plugin_distinfo -> list[tuple[(object, Any)]] {
    return `list(self._plugin_distinfo);
}

impl PluginManager.load_setuptools_entrypoints(group: str) -> int {
    count = 0;
    for dist in importlib.metadata.distributions() {
        for ep in dist.entry_points {
            if ep.group != group {
                continue;
            }
            if ep.name in self._name2plugin {
                continue;
            }
            try {
                plugin = ep.load();
            } except Exception {
                continue;
            }
            self.register(plugin, name=ep.name);
            self._plugin_distinfo.append((plugin, _DistFacade(_dist=dist)));
            count += 1;
        }
    }
    return count;
}

impl _DistFacade.project_name.getter -> str {
    return self._dist.metadata['Name'];
}

impl _DistFacade.version.getter -> str {
    return self._dist.metadata.get('Version', '0.0.0');
}

impl _DistFacade.__getattr__(attr: str) -> object {
    return getattr(self._dist, attr);
}
