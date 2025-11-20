"""Plugin for Jac's with_llm feature."""

from __future__ import annotations


from typing import Callable, TYPE_CHECKING

from jaclang.runtimelib.machine import hookimpl

if TYPE_CHECKING:
    from byllm.llm import Model
    from byllm.mtir import MTIR


class JacMachine:
    """Jac's with_llm feature."""

    @staticmethod
    @hookimpl
    def get_mtir(caller: Callable, args: dict, call_params: dict) -> object:
        """Call JacLLM and return the result."""
        from byllm.mtir import MTIR

        return MTIR.factory(caller, args, call_params)

    @staticmethod
    @hookimpl
    def call_llm(model: Model, mtir: MTIR) -> object:
        """Call JacLLM and return the result."""
        return model.invoke(mtir=mtir)

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
                mtir = MTIR.factory(
                    caller=caller,
                    args=invoke_args,
                    call_params=model.call_params,
                )
                return model.invoke(mtir=mtir)

            return _wrapped_caller

        return _decorator
