"""Implementation for plugin system."""

impl HookimplMarker.__call__(self: HookimplMarker, function: _F) -> _F {
    setattr(function, _IMPL_ATTR, True);
    return function;
}

impl HookspecMarker.__call__(
    self: HookspecMarker, function: (_F | None) = None, *, firstresult: bool = False
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

impl HookImpl.__repr__(self: HookImpl) -> str {
    return f"<HookImpl plugin_name={self.plugin_name!r}>";
}

impl HookCaller._add_hookimpl(self: HookCaller, hi: HookImpl) -> None {
    self._hookimpls.append(hi);
}

impl HookCaller._remove_plugin(self: HookCaller, plugin: object) -> None {
    self._hookimpls = [
        h
        for h in self._hookimpls
        if h.plugin is not plugin
    ];
}

impl HookCaller.get_hookimpls(self: HookCaller) -> list[HookImpl] {
    return `list(self._hookimpls);
}

impl HookCaller._call_impl(
    self: HookCaller, hi: HookImpl, kwargs: dict[(str, object)]
) -> object {
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

impl HookCaller.__call__(self: HookCaller, **kwargs: object) -> object {
    if self._firstresult {
        for hi in reversed(self._hookimpls) {
            result = self._call_impl(hi, kwargs);
            if result is not None {
                return result;
            }
        }
        return None;
    }
    results: list[Any] = [];
    for hi in reversed(self._hookimpls) {
        result = self._call_impl(hi, kwargs);
        if result is not None {
            results.append(result);
        }
    }
    return results;
}

impl HookCaller.__repr__(self: HookCaller) -> str {
    return f"<HookCaller {self.name!r}>";
}

impl PluginManager.register(
    self: PluginManager, plugin: object, name: (str | None) = None
) -> (str | None) {
    plugin_name = name or _canonical_name(plugin);
    if id(plugin) in self._plugin2name {
        return None;
    }
    self._name2plugin[plugin_name] = plugin;
    self._plugin2name[id(plugin)] = plugin_name;
    seen: set[str] = `set();
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
                hook = HookCaller(attr_name, firstresult=False);
                setattr(self.hook, attr_name, hook);
            }
            hook._add_hookimpl(hi);
        }
    }
    return plugin_name;
}

impl PluginManager.unregister(
    self: PluginManager, plugin: (object | None) = None, name: (str | None) = None
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
    for attr_name in `list(vars(self.hook)) {
        hook = getattr(self.hook, attr_name, None);
        if isinstance(hook, HookCaller) {
            hook._remove_plugin(plugin);
        }
    }
    return plugin;
}

impl PluginManager.is_registered(self: PluginManager, plugin: object) -> bool {
    return id(plugin) in self._plugin2name;
}

impl PluginManager.add_hookspecs(self: PluginManager, spec_class: type) -> None {
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
            hook = HookCaller(attr_name, firstresult=firstresult);
            setattr(self.hook, attr_name, hook);
        } else {
            hook._firstresult = firstresult;
        }
    }
}

impl PluginManager.list_name_plugin(self: PluginManager) -> list[tuple[(str, object)]] {
    return `list(self._name2plugin.items());
}

impl PluginManager.list_plugin_distinfo(
    self: PluginManager
) -> list[tuple[(object, Any)]] {
    return `list(self._plugin_distinfo);
}

impl PluginManager.load_setuptools_entrypoints(self: PluginManager, group: str) -> int {
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

@ property
impl _DistFacade.project_name(self: _DistFacade) -> str {
    return self._dist.metadata['Name'];
}

@ property
impl _DistFacade.version(self: _DistFacade) -> str {
    return self._dist.metadata.get('Version', '0.0.0');
}

impl _DistFacade.__getattr__(self: _DistFacade, attr: str) -> object {
    return getattr(self._dist, attr);
}
