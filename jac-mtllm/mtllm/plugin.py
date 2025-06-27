"""Plugin for Jac's with_llm feature."""

from typing import Callable

from jaclang.runtimelib.machine import hookimpl

from mtllm.llm import JacLLM

class JacMachine:
    """Jac's with_llm feature."""

    @staticmethod
    @hookimpl
    def call_llm(
        model: JacLLM, caller: Callable, args: dict[str | int, object]
    ) -> object:
        """Call JacLLM and return the result."""
        return model.invoke(caller, args)
