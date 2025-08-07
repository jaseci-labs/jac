"""LLM abstraction module.

This module provides a LLM class that abstracts LiteLLM and offers
enhanced functionality and interface for language model operations.
"""

# flake8: noqa: E402

import random
import json
import logging
import os
import time
from typing import Generator

from mtllm.mtir import MTIR

# This will prevent LiteLLM from fetching pricing information from
# the bellow URL every time we import the litellm and use a cached
# local json file. Maybe we we should conditionally enable this.
# https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json
os.environ["LITELLM_LOCAL_MODEL_COST_MAP"] = "True"

import litellm
from litellm import CustomStreamWrapper
from litellm._logging import _disable_debugging
from litellm.types.utils import Delta, ModelResponse

from .types import (
    CompletionResult,
    LiteLLMMessage,
    MockToolCall,
    ToolCall,
)

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
        # Every litellm call will be logged to the tty and that pollutes the output.
        # When there is a by llm() call in the jaclang.
        logging.getLogger("httpx").setLevel(logging.WARNING)
        _disable_debugging()

        self.model_name = model_name
        self.config = kwargs

        # The parameters for the llm call like temprature, top_k, max_token, etc.
        # This is only applicable for the next call passed from `by llm(**kwargs)`.
        self.call_params: dict[str, object] = {}

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
        self.call_params = kwargs
        return self

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

    def _get_dispatch_params(self, mtir: MTIR) -> dict[str, object]:
        return mtir.dispatch_params() | {
            "model": self.model_name,
            "api_base": self.config.get("host") or self.config.get("api_base"),
        }

    def _completion_no_streaming(self, mtir: MTIR) -> CompletionResult:
        """Perform a completion request with the LLM."""
        if self.model_name.lower().strip() == "mockllm":
            return self._dispatch_no_streaming_mock_response(mtir)  # type: ignore
        return self._dispatch_no_streaming_call(mtir)

    def _completion_streaming(self, mtir: MTIR) -> Generator[str, None, None]:
        """Perform a streaming completion request with the LLM."""
        if self.model_name.lower().strip() == "mockllm":
            return self._dispatch_streaming_mock_response(mtir)  # type: ignore
        return self._dispatch_streaming_response(mtir)

    def _dispatch_streaming_mock_response(
        self, mtir: MTIR
    ) -> Generator[str, None, None]:
        """Dispatch the mock LLM call with the given request."""
        output = self.config["outputs"].pop(0)  # type: ignore
        if mtir.stream:
            while output:
                chunk_len = random.randint(3, 10)
                yield output[:chunk_len]  # Simulate token chunk
                time.sleep(random.uniform(0.01, 0.05))  # Simulate network delay
                output = output[chunk_len:]

    def _dispatch_no_streaming_mock_response(self, mtir: MTIR) -> CompletionResult:
        """Dispatch the mock LLM call with the given request."""
        output = self.config["outputs"].pop(0)  # type: ignore

        if isinstance(output, MockToolCall):
            self._log_info(
                f"Mock LLM call completed with tool call:\n{output.to_tool_call()}"
            )
            return CompletionResult(
                output=None,
                tool_calls=[output.to_tool_call()],
            )

        self._log_info(f"Mock LLM call completed with response:\n{output}")

        return CompletionResult(
            output=output,
            tool_calls=[],
        )

    def _log_info(self, message: str) -> None:
        """Log a message to the console."""
        # FIXME: The logger.info will not always log so for now I'm printing to stdout
        # remove and log properly.
        if bool(self.config.get("verbose", False)):
            print(message)

    def _dispatch_no_streaming_call(self, mtir: MTIR) -> CompletionResult:
        # Construct the parameters for the LLM call
        # Call the LiteLLM API
        params = self._get_dispatch_params(mtir)
        self._log_info(f"Calling LLM: {self.model_name} with params:\n{params}")
        response = litellm.completion(**params)  # type: ignore

        # Output format:
        # https://docs.litellm.ai/docs/#response-format-openai-format
        #
        # TODO: Handle stream output (type ignoring stream response)
        message: LiteLLMMessage = response.choices[0].message  # type: ignore
        mtir.add_message(message)

        output_content: str = message.content or " "  # type: ignore
        self._log_info(f"LLM call completed with response:\n{output_content}")
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

    def _dispatch_streaming_response(self, mtir: MTIR) -> Generator[str, None, None]:
        params = self._get_dispatch_params(mtir)
        self._log_info(f"Calling LLM: {self.model_name} with params:\n{params}")
        response: CustomStreamWrapper = litellm.completion(**params, stream=True)  # type: ignore

        for chunk in response:
            if chunk.choices and chunk.choices[0].delta:
                delta: Delta = chunk.choices[0].delta
                yield delta.content or ""
