"""LLM abstraction module.

This module provides a LLM class that abstracts LiteLLM and offers
enhanced functionality and interface for language model operations.
"""

# flake8: noqa: E402

import os
from typing import Generator

from byllm.mtir import MTIR

# This will prevent LiteLLM from fetching pricing information from
# the bellow URL every time we import the litellm and use a cached
# local json file. Maybe we we should conditionally enable this.
# https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json
os.environ["LITELLM_LOCAL_MODEL_COST_MAP"] = "True"

from .llm_connector import LLMConnector
from .types import CompletionResult

SYSTEM_PERSONA = """\
This is a task you must complete by returning only the output.
Do not include explanations, code, or extra text—only the result.
"""  # noqa E501

INSTRUCTION_TOOL = """
Use the tools provided to reach the goal. Call one tool at a time with \
proper args—no explanations, no narration. Think step by step, invoking tools \
as needed. When done, always call finish_tool(output) to return the final \
output. Only use tools.
"""  # noqa E501


class Model:
    """A wrapper class that abstracts LiteLLM functionality.

    This class provides a simplified and enhanced interface for interacting
    with various language models through LiteLLM.
    """

    def __init__(self, model_name: str, **kwargs: object) -> None:
        """Initialize the JacLLM instance.

        Args:
            model: The model name to use (e.g., "gpt-3.5-turbo", "claude-3-sonnet-20240229")
            api_key: API key for the model provider
            **kwargs: Additional configuration options
        """
        self.llm_connector = LLMConnector.for_model(model_name, **kwargs)

    def __call__(self, **kwargs: object) -> "Model":
        """Construct the call parameters and return self (factory pattern).

        Example:
            ```jaclang
            llm = JacLLM(model="gpt-3.5-turbo", api_key="your_api_key")

            # The bellow call will construct the parameter and return self.
            def answer_user_query(query: str) -> str by
                llm(
                    temperature=0.7,
                    max_tokens=100,
                );
            ```
        """
        self.llm_connector.call_params = kwargs
        return self

    @property
    def call_params(self) -> dict[str, object]:
        """Get the call parameters for the LLM."""
        return self.llm_connector.call_params

    def invoke(self, mtir: MTIR) -> object:
        """Invoke the LLM with the given caller and arguments."""
        if mtir.stream:
            return self._completion_streaming(mtir)

        # Invoke the LLM and handle tool calls.
        while True:
            resp = self._completion_no_streaming(mtir)
            if resp.tool_calls:
                for tool_call in resp.tool_calls:
                    if tool_call.is_finish_call():
                        return tool_call.get_output()
                    else:
                        mtir.add_message(tool_call())
            else:
                break

        return resp.output

    def _completion_no_streaming(self, mtir: MTIR) -> CompletionResult:
        """Perform a completion request with the LLM."""
        return self.llm_connector.dispatch_no_streaming(mtir)

    def _completion_streaming(self, mtir: MTIR) -> Generator[str, None, None]:
        """Perform a streaming completion request with the LLM."""
        return self.llm_connector.dispatch_streaming(mtir)
