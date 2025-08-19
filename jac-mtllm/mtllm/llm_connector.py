"""LLM Connector for Litellm, MockLLM, Proxy server, etc.

This module provides an abstract base class for LLM connectors and concrete implementations
for different LLM services. It includes methods for dispatching requests and handling responses.
"""

# flake8: noqa: E402

import json
import logging
import os
import random
import time
from abc import ABC, abstractmethod
from typing import Generator, override

# This will prevent LiteLLM from fetching pricing information from
# the bellow URL every time we import the litellm and use a cached
# local json file. Maybe we we should conditionally enable this.
# https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json
os.environ["LITELLM_LOCAL_MODEL_COST_MAP"] = "True"

import litellm
from litellm._logging import _disable_debugging

from openai import OpenAI

from .mtir import MTIR

from .types import (
    CompletionResult,
    LiteLLMMessage,
    MockToolCall,
    ToolCall,
)

DEFAULT_BASE_URL = "http://localhost:4000"
MODEL_MOCK = "mockllm"


class LLMConnector(ABC):
    """Abstract base class for LLM connectors."""

    def __init__(self, model_name: str, **kwargs: object) -> None:
        """Initialize the LLM connector with a model."""
        self.model_name = model_name
        self.config = kwargs
        # The parameters for the llm call like temprature, top_k, max_token, etc.
        # This is only applicable for the next call passed from `by llm(**kwargs)`.
        self.call_params: dict[str, object] = {}

    @staticmethod
    def for_model(model_name: str, **kwargs: object) -> "LLMConnector":
        """Construct the appropriate LLM connector based on the model name."""
        if model_name.lower().strip() == MODEL_MOCK:
            return MockLLMConnector(model_name, **kwargs)
        if kwargs.get("proxy_url"):
            kwargs["base_url"] = kwargs.pop("proxy_url")
            return LiteLLMConnector(True, model_name, **kwargs)
        return LiteLLMConnector(False, model_name, **kwargs)

    def make_model_params(self, mtir: MTIR) -> dict:
        """Prepare the parameters for the LLM call."""
        params = {
            "model": self.model_name,
            "api_base": (
                self.config.get("base_url")
                or self.config.get("host")
                or self.config.get("api_base")
            ),
            "api_key": self.config.get("api_key"),
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

    @abstractmethod
    def dispatch_no_streaming(self, mtir: MTIR) -> CompletionResult:
        """Dispatch the LLM call without streaming."""
        raise NotImplementedError()

    @abstractmethod
    def dispatch_streaming(self, mtir: MTIR) -> Generator[str, None, None]:
        """Dispatch the LLM call with streaming."""
        raise NotImplementedError()


# -----------------------------------------------------------------------------
# Mock LLM Connector
# -----------------------------------------------------------------------------


class MockLLMConnector(LLMConnector):
    """LLM Connector for a mock LLM service that simulates responses."""

    @override
    def dispatch_no_streaming(self, mtir: MTIR) -> CompletionResult:
        """Dispatch the mock LLM call with the given request."""
        output = self.config["outputs"].pop(0)  # type: ignore

        if isinstance(output, MockToolCall):
            self.log_info(
                f"Mock LLM call completed with tool call:\n{output.to_tool_call()}"
            )
            return CompletionResult(
                output=None,
                tool_calls=[output.to_tool_call()],
            )

        self.log_info(f"Mock LLM call completed with response:\n{output}")

        return CompletionResult(
            output=output,
            tool_calls=[],
        )

    @override
    def dispatch_streaming(self, mtir: MTIR) -> Generator[str, None, None]:
        """Dispatch the mock LLM call with the given request."""
        output = self.config["outputs"].pop(0)  # type: ignore
        if mtir.stream:
            while output:
                chunk_len = random.randint(3, 10)
                yield output[:chunk_len]  # Simulate token chunk
                time.sleep(random.uniform(0.01, 0.05))  # Simulate network delay
                output = output[chunk_len:]


# -----------------------------------------------------------------------------
# LiteLLM Connector
# -----------------------------------------------------------------------------


class LiteLLMConnector(LLMConnector):
    """LLM Connector for LiteLLM, a lightweight wrapper around OpenAI API."""

    def __init__(self, proxy: bool, model_name: str, **kwargs: object) -> None:
        """Initialize the LiteLLM connector."""
        super().__init__(model_name, **kwargs)
        self.proxy = proxy

        # Every litellm call will be logged to the tty and that pollutes the output.
        # When there is a by llm() call in the jaclang.
        logging.getLogger("httpx").setLevel(logging.WARNING)
        _disable_debugging()
        litellm.drop_params = True

    @override
    def dispatch_no_streaming(self, mtir: MTIR) -> CompletionResult:
        """Dispatch the LLM call without streaming."""
        # Construct the parameters for the LLM call
        params = self.make_model_params(mtir)

        # Call the LiteLLM API
        self.log_info(f"Calling LLM: {self.model_name} with params:\n{params}")
        if self.proxy:
            client = OpenAI(
                base_url=params.pop("api_base", "htpp://localhost:4000"),
                api_key=params.pop("api_key"),
            )
            response = client.chat.completions.create(**params)
        else:
            response = litellm.completion(**params)

        # Output format:
        # https://docs.litellm.ai/docs/#response-format-openai-format
        #
        # TODO: Handle stream output (type ignoring stream response)
        message: LiteLLMMessage = response.choices[0].message  # type: ignore
        mtir.add_message(message)

        output_content: str = message.content  # type: ignore
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

    @override
    def dispatch_streaming(self, mtir: MTIR) -> Generator[str, None, None]:
        """Dispatch the LLM call with streaming."""
        # Construct the parameters for the LLM call
        params = self.make_model_params(mtir)

        # Call the LiteLLM API
        self.log_info(f"Calling LLM: {self.model_name} with params:\n{params}")
        if self.proxy:
            client = OpenAI(
                base_url=params.pop("api_base"),
                api_key=params.pop("api_key"),
            )

            # Call the LiteLLM API
            response = client.chat.completions.create(**params, stream=True)
        else:
            response = litellm.completion(**params, stream=True)  # type: ignore

        for chunk in response:
            if chunk.choices and chunk.choices[0].delta:
                delta = chunk.choices[0].delta
                yield delta.content or ""
