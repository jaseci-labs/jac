"""Plugin for Jac's with_llm feature."""
import from collections.abc { Callable }
import from typing { TYPE_CHECKING }
import from jaclang.runtimelib.runtime { hookimpl }

with entry {
    if TYPE_CHECKING {
        import from byllm.llm { Model }
        import from byllm.mtir { MTIR }
    }
}

"""Jac's with_llm feature."""
class JacRuntime {
    """Call JacLLM and return the result."""
    @staticmethod @hookimpl
    static def get_mtir(caller: Callable, args: dict, call_params: dict) -> object {
        import from byllm.mtir { MTIR }
        return MTIR.factory(caller, args, call_params);
    }

    """Call JacLLM and return the result."""
    @staticmethod @hookimpl
    static def call_llm(model: Model, mtir: MTIR) -> object {
        return model.invoke(mtir=mtir);
    }

    """Python library mode decorator for Jac's by llm() syntax."""
    @staticmethod @hookimpl
    static def by(model: Model) -> Callable {
        def _decorator(caller: Callable) -> Callable {
            def _wrapped_caller( *args: object , **kwargs: object)  -> object {
                import from byllm.mtir { MTIR }
                invoke_args: dict[(int | str, object)] = {};
                for (i, arg) in enumerate(args) {
                    invoke_args[i] = arg;
                }
                for (key, value) in kwargs.items() {
                    invoke_args[key] = value;
                }
                mtir = MTIR.factory(
                    caller=caller, args=invoke_args, call_params=model.call_params
                );
                return model.invoke(mtir=mtir);
            }
            return _wrapped_caller;
        }
        return _decorator;
    }
}
