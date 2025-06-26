"""Type definitions for LLM interactions.

This module defines the types used in the LLM interactions, including messages,
tools, and tool calls. It provides a structured way to represent messages,
tool calls, and tools that can be used in LLM requests and responses.
"""

from dataclasses import dataclass
from enum import StrEnum
from typing import Callable, TypeAlias, get_type_hints

from litellm.types.utils import Message as LiteLLMMessage

from pydantic import TypeAdapter

# The message can be a jaclang defined message or what ever the llm
# returned object that was feed back to the llm as it was given (dict).
MessageType: TypeAlias = "Message | LiteLLMMessage"


class MessageRole(StrEnum):
    """Enum for message roles in LLM interactions."""

    SYSTEM = "system"
    USER = "user"
    ASSISTANT = "assistant"
    TOOL = "tool"


@dataclass
class Message:
    """Message class for LLM interactions."""

    role: MessageRole
    content: str

    # Note: asdict() won't work with enum, so we need to define this method.
    def to_dict(self) -> dict[str, object]:
        """Convert the message to a dictionary."""
        return {
            "role": self.role.value,
            "content": self.content,
        }


@dataclass
class ToolCallResultMsg(Message):
    """Result of a tool call in LLM interactions."""

    tool_call_id: str
    name: str  # Function name.

    def __post_init__(self) -> None:
        """Post-initialization to set the role of the message."""
        self.role = MessageRole.TOOL  # Maybe this should be an assertion?

    def to_dict(self) -> dict[str, object]:
        """Convert the tool call result message to a dictionary."""
        return {
            "role": self.role.value,
            "content": self.content,
            "tool_call_id": self.tool_call_id,
            "name": self.name,
        }


@dataclass
class Tool:
    """Tool class for LLM interactions."""

    func: Callable
    description: str = ""
    params_desc: dict[str, str] = None  # type: ignore

    def __post_init__(self) -> None:
        """Post-initialization to validate the function."""
        self.func.__annotations__ = get_type_hints(self.func)
        self.description = Tool.get_func_description(self.func)
        if hasattr(self.func, "_jac_semstr_inner"):
            self.params_desc = self.func._jac_semstr_inner  # type: ignore
        else:
            self.params_desc = {
                name: str(type) for name, type in self.func.__annotations__.items()
            }

    def __call__(self, *args: list, **kwargs: dict) -> object:
        """Call the tool function with the provided arguments."""
        # If there is an error with the finish tool, we throw the exception.
        # Since it's the user's responsibility to handle it.
        if self.is_finish_tool():
            return self.func(*args, **kwargs)
        try:
            # TODO: Shoud I json serialize or this is fine?
            return self.func(*args, **kwargs)
        except Exception as e:
            # For the LLM if the tool failed, it'll see the error message
            # and make decision based on that.
            return str(e)

    def get_name(self) -> str:
        """Return the name of the tool function."""
        return self.func.__name__

    @staticmethod
    def get_func_description(func: Callable) -> str:
        """Get the description of the function."""
        if hasattr(func, "_jac_semstr"):
            return func._jac_semstr  # type: ignore
        return func.__doc__ or ""

    @staticmethod
    def make_finish_tool(resp_type: object) -> "Tool":
        """Create a finish tool that returns the final output."""

        def finish_tool(final_output: object) -> object:
            typeadop = TypeAdapter(resp_type)
            return typeadop.validate_python(final_output)

        finish_tool.__annotations__["return"] = resp_type
        finish_tool.__annotations__["final_output"] = resp_type
        return Tool(
            func=finish_tool,
            description="This tool is used to finish the tool calls and return the final output.",
            params_desc={
                "final_output": "The final output of the tool calls.",
            },
        )

    def is_finish_tool(self) -> bool:
        """Check if the tool is a finish tool."""
        return self.get_name() == "finish_tool"

    def get_json_schema(self) -> dict[str, object]:
        """Return the JSON schema for the tool function."""
        schema = TypeAdapter(self.func).json_schema()
        schema.pop("type", "")
        properties = schema.get("properties", {})
        for param_name, param_info in properties.items():
            param_info["description"] = self.params_desc.get(param_name, "")
        return {
            "type": "function",
            "function": {
                "name": self.func.__name__,
                "description": self.description,
                "parameters": {
                    "type": "object",
                    "properties": properties,
                },
            },
            "strict": True,
            **schema,
        }

    def parse_arguments(self, args_json: dict) -> dict:
        """Parse the arguments from JSON to the function's expected format."""
        args = {}
        annotations = self.func.__annotations__
        for arg_name, arg_json in args_json.items():
            if arg_type := annotations.get(arg_name):
                args[arg_name] = TypeAdapter(arg_type).validate_python(arg_json)
        return args


@dataclass
class ToolCall:
    """Tool call class for LLM interactions."""

    call_id: str
    tool: Tool
    args: dict

    def __call__(self) -> ToolCallResultMsg:
        """Call the tool with the provided arguments."""
        result = self.tool(**self.args)
        # params = ", ".join(f"{k}={v}" for k, v in self.args.items())
        # content=f"{self.tool.get_name()}({params}) = {result}"
        return ToolCallResultMsg(
            role=MessageRole.TOOL,
            content=str(result),
            tool_call_id=self.call_id,
            name=self.tool.get_name(),
        )

    def __str__(self) -> str:
        """Return the string representation of the tool call."""
        params = ", ".join(f"{k}={v}" for k, v in self.args.items())
        return f"{self.tool.get_name()}({params})"

    def is_finish_call(self) -> bool:
        """Check if the tool is a finish tool."""
        return self.tool.is_finish_tool()

    def get_output(self) -> object:
        """Get the output from the finish tool call."""
        assert (
            self.is_finish_call()
        ), "This method should only be called for finish tools."
        return self.tool(**self.args)


@dataclass
class CompletionRequest:
    """Request for completion from the LLM."""

    # The message can be both Message instance or a dictionary (that was
    # returned by the llm, and we're feeding back).
    messages: list[MessageType]
    tools: list[Tool]
    params: dict  # Additional parameters for the LLM request.
    resp_type: object | None = None  # Type from which the json schema is generated.

    def __post_init__(self) -> None:
        """Post-initialization to ensure the tools list contains a finish tool."""
        if len(self.tools) > 0:
            finish_tool = Tool.make_finish_tool(self.resp_type)
            self.tools.append(finish_tool)

    def get_msg_list(self) -> list[dict[str, object] | LiteLLMMessage]:
        """Return the messages in a format suitable for LLM API."""
        return [
            msg.to_dict() if isinstance(msg, Message) else msg for msg in self.messages
        ]

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
            return {
                "type": "json_schema",
                "json_schema": {
                    "schema": TypeAdapter(self.resp_type).json_schema(),
                },
                "strict": True,
            }
        # If the are tools, the final output will be sent to the finish_tool
        # thus there is no output schema.
        return None

    def parse_response(self, response: str) -> object:
        """Parse the response from the LLM."""
        # To use validate_json the string should contains quotes.
        #     example: '"The weather at New York is sunny."'
        # but the response from LLM will not have quotes, so
        # we need to check if it's string and return early.
        if self.resp_type is str or response.strip() == "":
            return response
        if self.resp_type:
            return TypeAdapter(self.resp_type).validate_json(response)
        return response

    def add_message(self, message: MessageType) -> None:
        """Add a message to the request."""
        self.messages.append(message)

    def get_tool(self, tool_name: str) -> Tool | None:
        """Get a tool by its name."""
        for tool in self.tools:
            if tool.func.__name__ == tool_name:
                return tool
        return None


@dataclass
class CompletionResult:
    """Result of the completion from the LLM."""

    output: object
    tool_calls: list[ToolCall]
