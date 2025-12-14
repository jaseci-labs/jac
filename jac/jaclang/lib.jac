"""Jac Library - User-friendly interface for library mode."""
import sys;
import from collections.abc { Callable }
import from contextlib { suppress }
import from typing { TYPE_CHECKING, cast }
import from jaclang.pycore.runtime { JacClassReferences, JacRuntimeInterface }
with entry {
    __all__ = [
        'Node',
        'Edge',
        'Walker',
        'Obj',
        'Root',
        'GenericEdge',
        'OPath',
        'DSFunc',
        'root',
        'spawn',
        'visit',
        'disengage',
        'connect',
        'disconnect',
        'create_j_context',
        'get_context',
        'reset_machine'
    ];
    if TYPE_CHECKING {
        import from jaclang.pycore.runtime { JacRuntimeInterface as JacRT }
        import from jaclang.runtimelib.archetype { GenericEdge, Root }
        import from jaclang.runtimelib.archetype { ObjectSpatialFunction as DSFunc }
        import from jaclang.runtimelib.archetype { ObjectSpatialPath as OPath }
        import from jaclang.runtimelib.constructs { Archetype as Obj }
        import from jaclang.runtimelib.constructs { EdgeArchetype as Edge }
        import from jaclang.runtimelib.constructs { NodeArchetype as Node }
        import from jaclang.runtimelib.constructs { WalkerArchetype as Walker }
        connect: Callable[(..., object)] = JacRT.connect;
        create_j_context: Callable[(..., object)] = JacRT.create_j_context;
        disconnect: Callable[(..., object)] = JacRT.disconnect;
        <>disengage: Callable[(..., object)] = JacRT.disengage;
        get_context: Callable[(..., object)] = JacRT.get_context;
        reset_machine: Callable[(..., object)] = JacRT.reset_machine;
        <>root: Callable[(..., object)] = JacRT.root;
        <>spawn: Callable[(..., object)] = JacRT.spawn;
        <>visit: Callable[(..., object)] = JacRT.visit;
    }
}

"""Lazy attribute access to initialize imports when needed."""
def __getattr__(name: str) -> object {
    if name.startswith('_') {
        raise AttributeError(f"module '{__name__}' has no attribute '{name}'") ;
    }
    import from jaclang.pycore.runtime { _init_lazy_imports, _lazy_imports_initialized }
    _init_lazy_imports();
    try {
        value = JacClassReferences.__getattr__(name);
        if _lazy_imports_initialized {
            globals()[name] = value;
        }
        return value;
    } except AttributeError {
        ;
    }
    if hasattr(JacRuntimeInterface, name) {
        value = getattr(JacRuntimeInterface, name);
        if _lazy_imports_initialized {
            globals()[name] = value;
        }
        return value;
    }
    raise AttributeError(f"module '{__name__}' has no attribute '{name}'") ;
}

"""Return list of available attributes."""
def __dir__()  -> list[str] {
    import from jaclang.pycore.runtime { _init_lazy_imports }
    _init_lazy_imports();
    return sorted(
        [
            name
            for name in dir(JacRuntimeInterface)
            if not name.startswith('_')
        ]
    );
}

"""Populate the module namespace with class and method references."""
def _populate_namespace()  -> None {
    current_module = sys.modules[__name__];
    class LazyRef {
        def __init__(self: LazyRef, attr_name: str) -> None {
            self.attr_name = attr_name;
            self._resolved: (object | None) = None;
        }

        def _resolve(self: LazyRef) -> object {
            if (self._resolved is None) {
                self._resolved = current_module.__getattr__(self.attr_name);
                setattr(current_module, self.attr_name, self._resolved);
            }
            return self._resolved;
        }

        def __call__(self: LazyRef, *args: object, **kwargs: object) -> object {
            resolved = cast(Callable[..., object], self._resolve());
            return resolved(*args, **kwargs);
        }

        def __getattr__(self: LazyRef, name: str) -> object {
            return getattr(self._resolve(), name);
        }

        def __mro_entries__(self: LazyRef, bases: tuple[type, ...]) -> tuple[type, ...] {
            return (cast(type, self._resolve()), );
        }
    }
    for name in __all__ {
        if not hasattr(current_module, name) {
            setattr(current_module, name, LazyRef(name));
        }
    }
}

with entry {
    ;
}
