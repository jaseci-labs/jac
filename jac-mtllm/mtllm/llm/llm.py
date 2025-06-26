"""LLM abstraction module.

This module provides a LLM class that abstracts LiteLLM and offers
enhanced functionality and interface for language model operations.
"""

import inspect
import json
from typing import Callable, get_type_hints

import litellm
from litellm._logging import _disable_debugging

from .types import (
    CompletionRequest,
    CompletionResult,
    LiteLLMMessage,
    Message,
    MessageRole,
    MessageType,
    Tool,
    ToolCall,
)

_disable_debugging()


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


class JacLLM:
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
        self.model_name = model_name
        self.config = kwargs

        # The parameters for the llm call like temprature, top_k, max_token, etc.
        # This is only applicable for the next call passed from `by llm(**kwargs)`.
        self.call_params: dict[str, object] = {}

    def __call__(self, **kwargs: object) -> "JacLLM":
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

    def invoke(self, caller: Callable, args: dict[str | int, object]) -> object:
        """Invoke the LLM with the given caller and arguments."""
        # Prepare the tools for the LLM call.
        tools = [
            Tool(func) for func in self.call_params.get("tools", [])  # type: ignore
        ]

        # Construct the input information from the arguments.
        param_names = list(inspect.signature(caller).parameters.keys())
        inputs_detail: list[str] = []
        for key, value in args.items():
            if isinstance(key, str):
                inputs_detail.append(f"{key} = {value}")
            else:
                # TODO: Handle *args, **kwargs properly.
                if key < len(param_names):
                    inputs_detail.append(f"{param_names[key]} = {value}")
                else:
                    inputs_detail.append(f"arg = {value}")

        # Prepare the messages for the LLM call.
        messages: list[MessageType] = [
            Message(
                role=MessageRole.SYSTEM,
                content=SYSTEM_PERSONA + (INSTRUCTION_TOOL if tools else ""),
            ),
            Message(
                role=MessageRole.USER,
                content=(
                    Tool.get_func_description(caller)
                    + "\n\n"
                    + "\n".join(inputs_detail)
                ),
            ),
        ]

        # Prepare the llm call request.
        req = CompletionRequest(
            messages=messages,
            tools=tools,
            resp_type=get_type_hints(caller).get("return"),
            params={},
        )

        # Invoke the LLM and handle tool calls.
        while True:
            resp = self.completion(req)
            if resp.tool_calls:
                for tool_call in resp.tool_calls:
                    if tool_call.is_finish_call():
                        return tool_call.get_output()
                    else:
                        req.add_message(tool_call())
            else:
                break

        return resp.output

    def completion(self, req: CompletionRequest) -> CompletionResult:
        """Perform a completion request with the LLM."""
        # Prepare the parameters for the LLM call
        params = {
            "model": self.model_name,
            "api_base": self.config.get("host") or self.config.get("api_base"),
            "messages": req.get_msg_list(),
            "tools": req.get_tool_list() or None,
            "response_format": req.get_output_schema(),
            "temperature": self.call_params.get("temperature", 0.7),
            # "max_tokens": self.call_params.get("max_tokens", 100),
            # "top_k": self.call_params.get("top_k", 50),
            # "top_p": self.call_params.get("top_p", 0.9),
        }

        # Call the LiteLLM API
        output = litellm.completion(**params)

        # Output format:
        # https://docs.litellm.ai/docs/#response-format-openai-format
        #
        # TODO: Handle stream output (type ignoring stream response)
        message: LiteLLMMessage = output.choices[0].message  # type: ignore
        req.add_message(message)

        output_content: str = message.content  # type: ignore
        output_value = req.parse_response(output_content)

        tool_calls: list[ToolCall] = []
        for tool_call in message.tool_calls or []:  # type: ignore
            if tool := req.get_tool(tool_call["function"]["name"]):
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
