import importlib;
import importlib.abc;
import importlib.util;
import logging;
import sys;
import threading;

glob _log: logging.Logger = logging.getLogger(__name__),
     _hooks: dict[str, list[any]] = {},
     _fired: set[str] = set(),
     _lock: any = threading.RLock(),
     _state: dict[str, any] = {"watcher": None};

def is_installed(name: str) -> bool {
    if name in sys.modules {
        return True;
    }
    try {
        return importlib.util.find_spec(name) is not None;
    } except (ImportError, ValueError) {
        return False;
    }
}

def _fire(name: str, module: any) -> None {
    with _lock {
        if name in _fired {
            return;
        }
        _fired.add(name);
        callbacks: list[any] = list(_hooks.pop(name, []));
    }
    for cb in callbacks {
        try {
            cb(module);
        } except Exception as e {
            _log.warning(f"on-load hook for {name} failed: {e}");
        }
    }
}

class _NotifyingLoader(importlib.abc.Loader) {
    def init(self: any, inner: any, name: str) {
        self._inner = inner;
        self._name = name;
    }

    def create_module(self: any, spec: any) -> any {
        return self._inner.create_module(spec);
    }

    def exec_module(self: any, module: any) {
        module.__loader__ = self._inner;
        if module.__spec__ is not None {
            module.__spec__.loader = self._inner;
        }
        self._inner.exec_module(module);
        _fire(self._name, module);
    }

    def __getattr__(self: any, attr: str) -> any {
        return getattr(self._inner, attr);
    }
}

class _LoadWatcher(importlib.abc.MetaPathFinder) {
    def find_spec(
        self: any, fullname: str, path: any = None, target: any = None
    ) -> any {
        if fullname not in _hooks or fullname in _fired {
            return None;
        }
        for finder in list(sys.meta_path) {
            if finder is self or not hasattr(finder, "find_spec") {
                continue;
            }
            spec = finder.find_spec(fullname, path, target);
            if spec is None {
                continue;
            }
            if spec.loader is not None and hasattr(spec.loader, "exec_module") {
                spec.loader = _NotifyingLoader(spec.loader, fullname);
            }
            return spec;
        }
        return None;
    }
}

def when_loaded(name: str, callback: any) -> None {
    with _lock {
        loaded = sys.modules.get(name);
        if loaded is None {
            pending = _hooks.setdefault(name, []);
            if callback not in pending {
                pending.append(callback);
            }
            if _state["watcher"] is None {
                _state["watcher"] = _LoadWatcher();
                sys.meta_path.insert(0, _state["watcher"]);
            }
            return;
        }
    }
    callback(loaded);
}

def is_loaded(name: str) -> bool {
    return name in sys.modules;
}

class DeferredModule {
    def init(self: any, name: str) {
        object.__setattr__(self, "_deferred_name", name);
        object.__setattr__(self, "_deferred_module", None);
    }

    def _deferred_load(self: any) -> any {
        module = object.__getattribute__(self, "_deferred_module");
        if module is None {
            module = importlib.import_module(
                object.__getattribute__(self, "_deferred_name")
            );
            object.__setattr__(self, "_deferred_module", module);
        }
        return module;
    }

    def __getattr__(self: any, attr: str) -> any {
        return getattr(self._deferred_load(), attr);
    }

    def __setattr__(self: any, attr: str, value: any) {
        setattr(self._deferred_load(), attr, value);
    }

    def __delattr__(self: any, attr: str) {
        delattr(self._deferred_load(), attr);
    }

    def __dir__(self: any) -> list[str] {
        return dir(self._deferred_load());
    }

    def __repr__(self: any) -> str {
        name = object.__getattribute__(self, "_deferred_name");
        return "<deferred module " + repr(name) + ">";
    }
}

def _resolve(module_name: str, path: str, load: bool) -> any {
    module = sys.modules.get(module_name);
    if module is None {
        if not load {
            return None;
        }
        module = importlib.import_module(module_name);
    }
    target = module;
    for part in path.split(".") {
        target = getattr(target, part);
    }
    return target;
}

class DeferredClassMeta(type) {
    def __instancecheck__(cls: any, candidate: any) -> bool {
        real = _resolve(cls._deferred_module, cls._deferred_path, False);
        return real is not None and isinstance(candidate, real);
    }

    def __subclasscheck__(cls: any, sub: any) -> bool {
        real = _resolve(cls._deferred_module, cls._deferred_path, False);
        return real is not None and issubclass(sub, real);
    }

    def __call__(cls: any, *args: any, **kwargs: any) -> any {
        return _resolve(cls._deferred_module, cls._deferred_path, True)(
            *args, **kwargs
        );
    }
}
