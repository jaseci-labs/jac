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
    @staticmethod @hookimpl
    static def get_mtir(caller: Callable, args: dict, call_params: dict) -> object {
        import from byllm.mtir { MTIR, MTRuntime }
        return MTIR(caller, args, call_params).runtime;
    }

    """Call JacLLM and return the result."""
    @staticmethod @hookimpl
    static def call_llm(model: Model, mtir: MTRuntime) -> object {
        return model.invoke(mtir=mtir);
    }

    """Python library mode decorator for Jac's by llm() syntax."""
    @staticmethod @hookimpl
    static def by(model: Model) -> Callable {
        def _decorator(caller: Callable) -> Callable {
            def _wrapped_caller( *args: object , **kwargs: object)  -> object {
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
}
