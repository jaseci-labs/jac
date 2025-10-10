"""Plugin for Jac's with_llm feature."""

from typing import Callable

from byllm.llm import Model
from byllm.mtir import MTIR

from jaclang.runtimelib.machine import hookimpl


class JacMachine:
    """Jac's with_llm feature."""

    @staticmethod
    @hookimpl
    def get_mtir(caller: Callable, args: dict, call_params: dict) -> object:
        """Call JacLLM and return the result."""
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
                invoke_args: dict[int | str, object] = {}
                for i, arg in enumerate(args):
                    invoke_args[i] = arg
                for key, value in kwargs.items():
                    invoke_args[key] = value
                mtir = MTIR.factory(
                    caller=caller,
                    args=invoke_args,
                    call_params=model.llm_connector.call_params,
                )
                return model.invoke(mtir=mtir)

            return _wrapped_caller

        return _decorator
