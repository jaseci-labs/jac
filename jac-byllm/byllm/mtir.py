"""MTIR (Meaning Typed Intermediate Representation) module for JacLang runtime library."""

import inspect
import json
from dataclasses import dataclass
from types import MethodType
from typing import Callable, get_type_hints

from byllm.schema import json_to_instance, type_to_schema
from byllm.types import (
    LiteLLMMessage,
    Media,
    Message,
    MessageRole,
    MessageType,
    Text,
    Tool,
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


@dataclass
class MTIR:
    """A class representing the MTIR for JacLang."""

    # All the context required to dispatch an LLM invocation.
    messages: list[MessageType]
    resp_type: type | None
    stream: bool
    tools: list[Tool]
    call_params: dict[str, object]

    # FIXME: Comeup with a better name
    @staticmethod
    def factory(
        caller: Callable, args: dict[int | str, object], call_params: dict[str, object]
    ) -> "MTIR":
        """Create an MTIR instance."""
        # Prepare the tools for the LLM call.
        tools = [Tool(func) for func in call_params.get("tools", [])]  # type: ignore

        # Construct the input information from the arguments.
        param_names = list(inspect.signature(caller).parameters.keys())
        inputs_detail: list[str] = []
        media_inputs: list[Media] = []

        for key, value in args.items():
            if isinstance(value, Media):
                media_inputs.append(value)
                continue

            if isinstance(key, str):
                inputs_detail.append(f"{key} = {value}")
            else:
                # TODO: Handle *args, **kwargs properly.
                if key < len(param_names):
                    inputs_detail.append(f"{param_names[key]} = {value}")
                else:
                    inputs_detail.append(f"arg = {value}")
        incl_info = call_params.get("incl_info")
        if incl_info and isinstance(incl_info, dict):
            for key, value in incl_info.items():
                if isinstance(value, Media):
                    media_inputs.append(value)
                else:
                    inputs_detail.append(f"{key} = {value}")

        if isinstance(caller, MethodType):
            inputs_detail.insert(0, f"self = {caller.__self__}")

        # Prepare the messages for the LLM call.
        messages: list[MessageType] = [
            Message(
                role=MessageRole.SYSTEM,
                content=SYSTEM_PERSONA + (INSTRUCTION_TOOL if tools else ""),
            ),
            Message(
                role=MessageRole.USER,
                content=[
                    Text(
                        Tool.get_func_description(caller)
                        + "\n\n"
                        + "\n".join(inputs_detail)
                    ),
                    *media_inputs,
                ],
            ),
        ]

        # Prepare return type.
        return_type = get_type_hints(caller).get("return")
        is_streaming = bool(call_params.get("stream", False))

        if is_streaming:
            if return_type is not str:
                raise RuntimeError(
                    "Streaming responses are only supported for str return types."
                )
            if tools:
                raise RuntimeError(
                    "Streaming responses are not supported with tool calls yet."
                )

        # TODO: Support mockllm for mocktesting.
        # Invoke streaming request, this will result in a generator that the caller
        # should either do .next() or .__iter__() by calling `for tok in resp: ...`
        if is_streaming and tools:
            raise RuntimeError(
                "Streaming responses are not supported with tool calls yet."
            )

        if len(tools) > 0:
            finish_tool = Tool.make_finish_tool(return_type or str)
            tools.append(finish_tool)

        return MTIR(
            messages=messages,
            tools=tools,
            resp_type=return_type,
            stream=is_streaming,
            call_params=call_params,
        )

    def dispatch_params(self) -> dict[str, object]:
        """Dispatch the parameters for the MTIR."""
        params = {
            "messages": self.get_msg_list(),
            "tools": self.get_tool_list() or None,
            "response_format": self.get_output_schema(),
            "temperature": self.call_params.get("temperature", 0.7),
            # "max_tokens": self.call_params.get("max_tokens", 100),
            # "top_k": self.call_params.get("top_k", 50),
            # "top_p": self.call_params.get("top_p", 0.9),
        }
        return params

    def add_message(self, message: MessageType) -> None:
        """Add a message to the request."""
        self.messages.append(message)

    def get_msg_list(self) -> list[dict[str, object] | LiteLLMMessage]:
        """Return the messages in a format suitable for LLM API."""
        return [
            msg.to_dict() if isinstance(msg, Message) else msg for msg in self.messages
        ]

    def parse_response(self, response: str) -> object:
        """Parse the response from the LLM."""
        # To use validate_json the string should contains quotes.
        #     example: '"The weather at New York is sunny."'
        # but the response from LLM will not have quotes, so
        # we need to check if it's string and return early.
        if self.resp_type is None or self.resp_type is str or response.strip() == "":
            return response
        if self.resp_type:
            json_dict = json.loads(response)
            return json_to_instance(json_dict, self.resp_type)
        return response

    def get_tool(self, tool_name: str) -> Tool | None:
        """Get a tool by its name."""
        for tool in self.tools:
            if tool.func.__name__ == tool_name:
                return tool
        return None

    def get_tool_list(self) -> list[dict]:
        """Return the tools in a format suitable for LLM API."""
        return [tool.get_json_schema() for tool in self.tools]

    def get_output_schema(self) -> dict | None:
        """Return the JSON schema for the response type."""
        assert (
            len(self.tools) == 0 or self.get_tool("finish_tool") is not None
        ), "Finish tool should be present in the tools list."
        if len(self.tools) == 0 and self.resp_type:
            if self.resp_type is str:
                return None  # Strings are default and not using a schema.
            return type_to_schema(self.resp_type)
        # If the are tools, the final output will be sent to the finish_tool
        # thus there is no output schema.
        return None
