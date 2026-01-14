"""Plugin for Jac's with_llm feature."""

from __future__ import annotations

from collections.abc import Callable
from typing import TYPE_CHECKING
import inspect
import sys
from pathlib import Path
from jaclang.pycore.runtime import hookimpl, JacRuntime as Jac
from jaclang.pycore.mtp import Info
if TYPE_CHECKING:
    from byllm.llm import Model
    from byllm.mtir import MTRuntime


def fetch_mtir(func: Callable) -> Info:
    def resolve_module(f: Callable) -> str:
        module_name = getattr(f, "__module__", None)
        if module_name and module_name != "__main__":
            return module_name
        # Try to get the module object
        mod = inspect.getmodule(f)
        if mod and getattr(mod, "__name__", None) != "__main__":
            return mod.__name__
        # Fall back to the source file name (script filename without suffix)
        try:
            file = inspect.getsourcefile(f) or inspect.getfile(f)
        except TypeError:
            file = None
        if file:
            return Path(file).stem
        # As a last resort, use the invoked script name from argv
        return Path(sys.argv[0]).stem if sys.argv and sys.argv[0] else "__main__"

    module = resolve_module(func)
    qualname = func.__qualname__
    from jaclang.pycore.runtime import JacRuntime as Jac

    ir = Jac.program.mod
    if module == "__main__" and ir.main:
        module = ir.main
    else:
        module = ir.hub.get(module)  # TODO Test external modules
    scopes = qualname.split(".")
    current_scope = module
    for scope in scopes[:-1]:
        lookup = current_scope.lookup(scope)
        if lookup:
            current_scope = lookup.symbol_table
    current_scope = current_scope.lookup(scopes[-1]).symbol_table
    ir_info = Jac.get_mtir_from_map(current_scope)
    return ir_info


class JacRuntime:
    """Jac's with_llm feature."""

    @staticmethod
    @hookimpl
    def get_mtir(caller: Callable, args: dict, call_params: dict) -> object:
        """Call JacLLM and return the result."""
        from byllm.mtir import MTIR

        return MTIR(caller, args, call_params, fetch_mtir(caller)).runtime

    @staticmethod
    @hookimpl
    def call_llm(model: Model, mt_run: MTRuntime) -> object:
        """Call JacLLM and return the result."""
        return model.invoke(mt_run=mt_run)

    @staticmethod
    @hookimpl
    def by(model: Model) -> Callable:
        """Python library mode decorator for Jac's by llm() syntax."""

        def _decorator(caller: Callable) -> Callable:
            def _wrapped_caller(*args: object, **kwargs: object) -> object:
                from byllm.mtir import MTIR

                invoke_args: dict[int | str, object] = {}
                for i, arg in enumerate(args):
                    invoke_args[i] = arg
                for key, value in kwargs.items():
                    invoke_args[key] = value
                mtir = MTIR(
                    caller=caller,
                    args=invoke_args,
                    call_params=model.call_params,
                    ir_info=fetch_mtir(caller),
                ).runtime
                return model.invoke(mt_run=mtir.runtime)

            return _wrapped_caller

        return _decorator
