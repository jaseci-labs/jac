"""Plugin for Jac's with_llm feature."""
import from collections.abc { Callable }
import from typing { TYPE_CHECKING }
import from jaclang.pycore.runtime { hookimpl }

with entry {
    if TYPE_CHECKING {
        import from byllm.llm { Model }
        import from byllm.mtir { MTIR, MTRuntime }
    }
}

"""Jac's with_llm feature."""
class JacRuntime {
    """Call JacLLM and return the result."""
    @hookimpl
    static def get_mtir(caller: Callable, args: dict, call_params: dict) -> object {
        import from byllm.mtir { MTIR, MTRuntime }
        return MTIR(caller, args, call_params).runtime;
    }

    """Call JacLLM and return the result."""
    @hookimpl
    static def call_llm(model: Model, mtir: MTRuntime) -> object {
        return model.invoke(mtir=mtir);
    }

    """Python library mode decorator for Jac's by llm() syntax."""
    @hookimpl
    static def by(model: Model) -> Callable {
        def _decorator(caller: Callable) -> Callable {
            def _wrapped_caller(*args: object, **kwargs: object) -> object {
                import from byllm.mtir { MTIR, MTRuntime }
                invoke_args: dict[(int | str, object)] = {};
                for (i, arg) in enumerate(args) {
                    invoke_args[i] = arg;
                }
                for (key, value) in kwargs.items() {
                    invoke_args[key] = value;
                }
                mtir = MTIR(
                    caller=caller, args=invoke_args, call_params=model.call_params
                ).runtime;
                return model.invoke(mtir=mtir);
            }
            return _wrapped_caller;
        }
        return _decorator;
    }

    """by operator for LLM-guided routing."""
    @hookimpl
    static def by_operator(lhs: object, rhs: object) -> object {
        import from byllm.lib { MockLLM, Model }
        import from jaclang.pycore.archetype { NodeArchetype, EdgeArchetype }
        import from jaclang.pycore.runtime { JacByLLM }

        lhs_list = lhs if isinstance(lhs, list) else [lhs];
        if all(
            isinstance(element, (NodeArchetype, EdgeArchetype)) for element in lhs_list
        )
        and isinstance(rhs, (Model, MockLLM)) {
            return JacByLLM.filter_visitable_by(lhs_list, rhs);
        }
        raise NotImplementedError(
            "The 'by' operator requires visitable nodes on the left and an LLM model on the right."
        ) ;
    }
}
