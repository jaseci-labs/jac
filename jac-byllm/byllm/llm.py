"""LLM abstraction module.

This module provides a LLM class that abstracts LiteLLM and offers
enhanced functionality and interface for language model operations.
"""

from __future__ import annotations

# flake8: noqa: E402

import os
import json
from typing import Generator

from byllm.mtir import MTIR

# This will prevent LiteLLM from fetching pricing information from
# the bellow URL every time we import the litellm and use a cached
# local json file. Maybe we we should conditionally enable this.
# https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json
os.environ["LITELLM_LOCAL_MODEL_COST_MAP"] = "True"

from .llm_connector import LLMConnector
from .types import CompletionResult, ToolCall

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

class BaseLLM:
    """Base class for LLM implementations."""

    def __init__(self, model_name: str, **kwargs: object) -> None:
        """Initialize the LLM connector with a model."""
        self.model_name = model_name
        self.config = kwargs
        # The parameters for the llm call like temprature, top_k, max_token, etc.
        # This is only applicable for the next call passed from `by llm(**kwargs)`.
        self.call_params: dict[str, object] = {}


    def __call__(self, **kwargs: object) -> BaseLLM:
        """Construct the call parameters and return self (factory pattern)."""
        self.call_params = kwargs
        return self
    # @property
    # def call_params(self) -> dict[str, object]:
    #     """Get the call parameters for the LLM."""
    #     raise NotImplementedError("Subclasses must implement this method.")
    
    def invoke(self, mtir: MTIR) -> object:
        """Invoke the LLM with the given caller and arguments."""
        if mtir.stream:
            return self.completion_streaming(mtir)

        # Invoke the LLM and handle tool calls.
        while True:
            resp = self.completion_no_streaming(mtir)
            if resp.tool_calls:
                for tool_call in resp.tool_calls:
                    if tool_call.is_finish_call():
                        return tool_call.get_output()
                    else:
                        mtir.add_message(tool_call())
            else:
                break

        return resp.output
    
    # def _completion_no_streaming(self, mtir: MTIR) -> CompletionResult:
    #     """Perform a completion request with the LLM."""
    #     raise NotImplementedError("Subclasses must implement this method.")
    
    # def _completion_streaming(self, mtir: MTIR) -> Generator[str, None, None]:
    #     """Perform a streaming completion request with the LLM."""
    #     raise NotImplementedError("Subclasses must implement this method.")
    
    def make_model_params(self, mtir: MTIR) -> dict:
        """Prepare the parameters for the LLM call."""
        params = {
            "model": self.model_name,
            "api_base": (
                self.config.get("base_url")
                or self.config.get("host")
                or self.config.get("api_base")
            ),
            # "api_key": self.config.get("api_key"),
            "messages": mtir.get_msg_list(),
            "tools": mtir.get_tool_list() or None,
            "response_format": mtir.get_output_schema(),
            "temperature": self.call_params.get("temperature", 0.7),
            "max_tokens": self.call_params.get("max_tokens"),
            # "top_k": self.call_params.get("top_k", 50),
            # "top_p": self.call_params.get("top_p", 0.9),
        }
        return params
    
    def log_info(self, message: str) -> None:
        """Log a message to the console."""
        # FIXME: The logger.info will not always log so for now I'm printing to stdout
        # remove and log properly.
        if bool(self.config.get("verbose", False)):
            print(message)

    def dispatch_no_streaming(self, mtir: MTIR) -> CompletionResult:
        """Dispatch the LLM call without streaming."""
        # Construct the parameters for the LLM call
        params = self.make_model_params(mtir)

        # Call the LiteLLM API
        self.log_info(f"Calling LLM: {self.model_name} with params:\n{params}")
        self.api_key = params.get("api_key")
        self.response = self.model_call(params, stream=False)

        # Output format:
        # https://docs.litellm.ai/docs/#response-format-openai-format
        #
        # TODO: Handle stream output (type ignoring stream response)
        message: LiteLLMMessage = response.choices[0].message  # type: ignore
        mtir.add_message(message)

        output_content: str = message.content or ""  # type: ignore
        self.log_info(f"LLM call completed with response:\n{output_content}")
        output_value = mtir.parse_response(output_content)

        tool_calls: list[ToolCall] = []
        for tool_call in message.tool_calls or []:  # type: ignore
            if tool := mtir.get_tool(tool_call["function"]["name"]):
                args_json = json.loads(tool_call["function"]["arguments"])
                args = tool.parse_arguments(args_json)
                tool_calls.append(
                    ToolCall(call_id=tool_call["id"], tool=tool, args=args)
                )
            else:
                raise RuntimeError(
                    f"Attempted to call tool: '{tool_call['function']['name']}' which was not present."
                )

        return CompletionResult(
            output=output_value,
            tool_calls=tool_calls,
        )

    def dispatch_streaming(self, mtir: MTIR) -> Generator[str, None, None]:
        """Dispatch the LLM call with streaming."""
        # Construct the parameters for the LLM call
        params = self.make_model_params(mtir)

        # Call the LiteLLM API
        self.log_info(f"Calling LLM: {self.model_name} with params:\n{params}")
        self.api_key = params.get("api_key")
        response = self.model_call(params, stream=True)

        for chunk in response:
            if chunk.choices and chunk.choices[0].delta:
                delta = chunk.choices[0].delta
                yield delta.content or ""

    def model_call_no_stream(self, params: dict, stream: bool) -> dict:
        """Make a direct model call with the given parameters.
        Hanldle both streaming and non-streaming calls.
        """
        if stream:
            raise NotImplementedError("Subclasses must implement this method for LLM call with streaming.")
        else:
            raise NotImplementedError("Subclasses must implement this method for LLM call without streaming.")



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

    def __call__(self, **kwargs: object) -> Model:
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
