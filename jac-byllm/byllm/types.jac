"""Type definitions for LLM interactions.

This module defines the types used in the LLM interactions, including messages,
tools, and tool calls. It provides a structured way to represent messages,
tool calls, and tools that can be used in LLM requests and responses.
"""
import base64;
import mimetypes;
import os;
import from contextlib { suppress }
import from enum { StrEnum }
import from io { BytesIO }
import from typing { Callable, TypeAlias, get_type_hints }

import from PIL.Image { Image as PILImageCls }
import from PIL.Image { open as open_image }

import from litellm.types.utils { Message as LiteLLMMessage }
import from pydantic { TypeAdapter }
import from .schema { tool_to_schema }

# The message can be a jaclang defined message or what ever the llm
# returned object that was feed back to the llm as it was given (dict).
glob MessageType:
         TypeAlias = 'Message | LiteLLMMessage';

"""Enum for message roles in LLM interactions."""
enum MessageRole ( StrEnum ) {
    SYSTEM = "system",
    USER = "user",
    ASSISTANT = "assistant",
    TOOL = "tool"
}

"""Message class for LLM interactions."""
obj Message {
    has role: MessageRole,
        content: str | list[Media];

    def to_dict -> dict[str, object];
}

"""Result of a tool call in LLM interactions."""
obj ToolCallResultMsg(Message) {
    has tool_call_id: str,
        name: str;

    def postinit -> None;
    def to_dict -> dict[str, object];
}

"""Tool class for LLM interactions.

Wraps a callable function to be used as a tool in LLM interactions.
Provides JSON schema generation, argument parsing, and invocation capabilities.
"""
obj Tool {
    has func: Callable,
        description: str = "",
        params_desc: dict[(str, str)] = None;

    def postinit -> None;
    def __call__(*args: list, **kwargs: dict) -> object;
    def get_name -> str;
    static def get_func_description(func: Callable) -> str;
    static def make_finish_tool(resp_type: type) -> Tool;
    def is_finish_tool -> bool;
    def get_json_schema -> dict[str, object];
    def parse_arguments(args_json: dict) -> dict;
}

"""Tool call class for LLM interactions.

Represents an invocation of a tool with specific arguments.
Created from LLM responses and can be executed to get results.
"""
obj ToolCall {
    has call_id: str,
        tool: Tool,
        args: dict;

    def __call__ -> ToolCallResultMsg;
    def __str__ -> str;
    def is_finish_call -> bool;
    def get_output -> object;
}

"""Mock tool call for testing purposes.

Used with MockLLM to simulate tool calls in tests without actual LLM invocation.
"""
obj MockToolCall {
    has tool: Callable,
        args: dict;

    def to_tool_call -> ToolCall;
}

"""Result of the completion from the LLM."""
obj CompletionResult {
    has output: object,
        tool_calls: list[ToolCall];
}

# -----------------------------------------------------------------------------
# Media content types
# -----------------------------------------------------------------------------
"""Base class for message content.

Abstract base for all media types that can be included in LLM messages.
Subclasses must implement to_dict() for serialization.
"""
obj Media {
    def to_dict -> list[dict];
}

"""Text content in a message."""
obj Text(Media) {
    has text: str;

    def to_dict -> list[dict];
}

"""Image content in a message.

Supports various input formats including URLs, file paths, bytes, BytesIO,
os.PathLike, and PIL Image objects. Normalizes input into a data URL or
leaves remote/data URLs as-is.
"""
obj Image(Media) {
    has url:
        (
            "str | bytes | bytearray | memoryview | BytesIO | IO[bytes] | "
            "os.PathLike[str] | os.PathLike[bytes] | PILImageCls"
        ),
        mime_type: str | None = None;

    def postinit -> None;
    def _format_to_mime(fmt: str | None) -> str;
    def _data_url_from_bytes(data: bytes, fmt: str | None) -> str;
    def to_dict -> list[dict];
}

# Ref: https://cookbook.openai.com/examples/gpt_with_vision_for_video_understanding
"""Video content in a message.

Extracts frames at a specified FPS and encodes them as base64 images
for LLM processing. See OpenAI cookbook for vision with video understanding.
"""
obj Video(Media) {
    has path: str,
        fps: int = 1,
        _base64frames: list[str] | None = None;

    def postinit -> None;
    def load_frames -> None;
    def to_dict -> list[dict];
}
