"""Plugin for Jac's with_llm feature."""
import from collections.abc { Callable }
import from typing { TYPE_CHECKING }
import from jaclang.pycore.runtime { hookimpl, JacRuntime as Jac }
import from jaclang.pycore.mtp { Info }
import inspect;
import sys;
import from pathlib { Path }

with entry {
    if TYPE_CHECKING {
        import from byllm.llm { Model }
        import from byllm.mtir { MTIR, MTRuntime }
    }
}

"""Fetch MTIR from the map, returning None if not found (e.g., in Python lib mode)."""
def fetch_mtir(func: Callable) -> Info | None {
    # Resolve module name
    module_name = None;
    try {
        module_name = getattr(func, "__module__");
    } except AttributeError {
        module_name = None;
    }

    if module_name and module_name != "__main__" {
        module = module_name;
    } else {
        # Try to get the module object
        mod = inspect.getmodule(func);
        if mod and getattr(mod, "__name__", None) != "__main__" {
            module = mod.__name__;
        } else {
            # Fall back to the source file name (script filename without suffix)
            file = None;
            try {
                file = inspect.getsourcefile(func) or inspect.getfile(func);
            } except TypeError {
                file = None;
            }
            if file {
                module = Path(file).stem;
            } else {
                # As a last resort, use the invoked script name from argv
                module = Path(sys.argv[0]).stem
                if sys.argv and sys.argv[0]
                else "__main__";
            }
        }
    }

    try {
        qualname = func.__qualname__;
        current_scope = ".".join([module, qualname]);
        ir_info = Jac.get_mtir_from_map(current_scope);
        return ir_info;
    } except (KeyError, AttributeError) {
        # MTIR not found - function not compiled through Jac (e.g., Python library mode)
        return None;
    }
}

"""Jac's with_llm feature."""
class JacRuntime {
    """Call JacLLM and return the result."""
    @hookimpl
    static def get_mtir(caller: Callable, args: dict, call_params: dict) -> object {
        import from byllm.mtir { MTIR }
        return MTIR(caller, args, call_params, fetch_mtir(caller)).runtime;
    }

    """Call JacLLM and return the result."""
    @hookimpl
    static def call_llm(model: Model, mt_run: MTRuntime) -> object {
        return model.invoke(mt_run=mt_run);
    }

    """Python library mode decorator for Jac's by llm() syntax."""
    @hookimpl
    static def by(model: Model) -> Callable {
        def _decorator(caller: Callable) -> Callable {
            def _wrapped_caller(*args: object, **kwargs: object) -> object {
                import from byllm.mtir { MTIR }
                invoke_args: dict[(int | str, object)] = {};
                for (i, arg) in enumerate(args) {
                    invoke_args[i] = arg;
                }
                for (key, value) in kwargs.items() {
                    invoke_args[key] = value;
                }
                mtir = MTIR(
                    caller=caller,
                    args=invoke_args,
                    call_params=model.call_params,
                    ir_info=fetch_mtir(caller)
                ).runtime;
                return model.invoke(mt_run=mtir);
            }
            return _wrapped_caller;
        }
        return _decorator;
    }

    """by operator for LLM-guided routing."""
    @hookimpl
    static def by_operator(lhs: object, rhs: object) -> object {
        import from byllm.llm { BaseLLM }
        import from jaclang.pycore.archetype { NodeArchetype, EdgeArchetype }
        import from jaclang.pycore.runtime { JacByLLM }

        lhs_list = lhs if isinstance(lhs, list) else [lhs];
        if all(
            isinstance(element, (NodeArchetype, EdgeArchetype)) for element in lhs_list
        )
        and isinstance(rhs, BaseLLM) {
            return JacByLLM.filter_visitable_by(lhs_list, rhs);
        }
        raise NotImplementedError(
            "The 'by' operator requires visitable nodes on the left and an LLM model on the right."
        ) ;
    }
}
