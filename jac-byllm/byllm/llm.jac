"""LLM abstraction module.

This module provides a LLM class that abstracts LiteLLM and offers
enhanced functionality and interface for language model operations.
"""

import logging;
import from loguru { logger }
import os;
import sys;
import json;
import random;
import time;

import from typing { Generator }
import from byllm.mtir { MTRuntime }
import litellm;
import from litellm._logging { _disable_debugging }
import from openai { OpenAI }
import from byllm.types {
    CompletionResult,
    LiteLLMMessage,
    MockToolCall,
    ToolCall,
    Message,
    MessageRole
}
# This will prevent LiteLLM from fetching pricing information from
# the bellow URL every time we import the litellm and use a cached
# local json file. Maybe we we should conditionally enable this.
# https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json
with entry {
    os.environ["LITELLM_LOCAL_MODEL_COST_MAP"] = "True";
}

glob DEFAULT_BASE_URL = "http://localhost:4000";
glob MODEL_MOCK = "mockllm";

glob SYSTEM_PERSONA = """\
This is a task you must complete by returning only the output.
Do not include explanations, code, or extra text—only the result.
""";  # noqa E501


glob INSTRUCTION_TOOL = """
Use the tools provided to reach the goal. Call one tool at a time with \
proper args—no explanations, no narration. Think step by step, invoking tools \
as needed. When done, always call finish_tool(output) to return the final \
output. Only use tools.
""";  # noqa E501


"""Base class for LLM implementations."""
obj BaseLLM {
    def init(model_name: str, **kwargs: object) -> None;
    """Construct the call parameters and return self (factory pattern)."""
    def __call__( **kwargs: object)  -> BaseLLM;

    """Invoke the LLM with the given MTRuntime."""
    def invoke(mtir: MTRuntime) -> object;

    """Prepare the parameters for the LLM call."""
    def make_model_params(mtir: MTRuntime) -> dict;

    """Log a message to the console."""
    def log_info(message: str) -> None;

    """Format model parameters for logging, masking sensitive information."""
    def format_prompt(params: dict) -> str;

    """Dispatch the LLM call without streaming."""
    def dispatch_no_streaming(mtir: MTRuntime) -> CompletionResult;

    """Dispatch the LLM call with streaming."""
    def dispatch_streaming(mtir: MTRuntime) -> Generator[str, None, None];

    """Make a direct model call with the given parameters.
    Get api_key from self.api_key if needed.
    """
    def model_call_no_stream(params: dict) -> dict;

    """Make a direct model call with the given parameters.
    Get api_key from self.api_key if needed.
    """
    def model_call_with_stream(params: dict) -> Generator[str, None, None];

    """Stream the final answer after ReAct tool calls complete.

    This creates a new streaming LLM call with all the context from tool calls
    to generate the final answer in real-time streaming mode.

    The difference from _stream_finish_output:
    - This makes a REAL streaming API call to the LLM
    - _stream_finish_output just splits an already-complete string
    """
    def _stream_final_answer(mtir: MTRuntime) -> Generator[str, None, None];
}

"""LLM Connector for a mock LLM service that simulates responses."""
obj MockLLM(BaseLLM) {
    """Initialize the MockLLM connector."""
    def init(model_name: str, **kwargs: object) -> None;

    """Dispatch the mock LLM call with the given request."""
    override def dispatch_no_streaming(mtir: MTRuntime) -> CompletionResult;

    """Dispatch the mock LLM call with the given request."""
    override def dispatch_streaming(mtir: MTRuntime) -> Generator[str, None, None];
}

"""A wrapper class that abstracts LiteLLM functionality.

This class provides a simplified and enhanced interface for interacting
with various language models through LiteLLM.
"""
obj Model(BaseLLM) {
    """Initialize the JacLLM instance.
    Args:
        model: The model name to use (e.g., "gpt-3.5-turbo", "claude-3-sonnet-20240229")
        api_key: API key for the model provider
        **kwargs: Additional configuration options
    """
    def init(model_name: str, **kwargs: object) -> None;

    """Invoke the LLM, delegating to MockLLM if applicable."""
    override def invoke(mtir: MTRuntime) -> object;

    def model_call_no_stream(params: dict) -> dict;
    def model_call_with_stream(params: dict);
}
