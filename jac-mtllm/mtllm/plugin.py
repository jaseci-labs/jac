"""Plugin for Jac's with_llm feature."""

from typing import Callable

from jaclang.runtimelib.machine import hookimpl

from mtllm.llm import Model
from mtllm.mtir import MTIR


class JacMachine:
    """Jac's with_llm feature."""

    @staticmethod
    @hookimpl
    def call_llm(
        model: Model, caller: Callable, args: dict[str | int, object]
    ) -> object:
        """Call JacLLM and return the result."""
        mtir = MTIR.factory(
            caller=caller,
            args=args,
            call_params=model.call_params,
        )
        return model.invoke(mtir=mtir)


def by(model: Model) -> Callable:
    """Python library mode decorator for Jac's by llm() syntax."""

    def _decorator(caller: Callable) -> Callable:
        def _wrapped_caller(*args: object, **kwargs: object) -> object:
            invoke_args: dict[int | str, object] = {}
            for i, arg in enumerate(args):
                invoke_args[i] = arg
            for key, value in kwargs.items():
                invoke_args[key] = value
            return JacMachine.call_llm(model, caller, invoke_args)

        return _wrapped_caller

    return _decorator
