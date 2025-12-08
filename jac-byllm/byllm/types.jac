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
    has role: MessageRole;
    has content: str | list[Media];

    """Convert the message to a dictionary."""
    def to_dict()  -> dict[str, object];
}

"""Result of a tool call in LLM interactions."""
obj ToolCallResultMsg(Message) {
    has tool_call_id: str;
    has name: str;  # Function name.

    """Post-initialization to set the role of the message."""
    def postinit()  -> None;

    """Convert the tool call result message to a dictionary."""
    def to_dict()  -> dict[str, object];
}

"""Tool class for LLM interactions."""
obj Tool {
    has func: Callable;
    has description: str = "";
    has params_desc: dict[str, str] = None;  # type: ignore

    """Post-initialization to validate the function."""
    def postinit()  -> None;

    """Call the tool function with the provided arguments."""
    def __call__( *args: list , **kwargs: dict)  -> object;

    """Return the name of the tool function."""
    def get_name()  -> str;

    """Get the description of the function."""
    static def get_func_description(func: Callable) -> str;

    """Create a finish tool that returns the final output."""
    static def make_finish_tool(resp_type: type) -> Tool;

    """Check if the tool is a finish tool."""
    def is_finish_tool()  -> bool;

    """Return the JSON schema for the tool function."""
    def get_json_schema()  -> dict[str, object];

    """Parse the arguments from JSON to the function's expected format."""
    def parse_arguments(args_json: dict) -> dict;
}

"""Tool call class for LLM interactions."""
obj ToolCall {
    has call_id: str;
    has tool: Tool;
    has args: dict;

    """Call the tool with the provided arguments."""
    def __call__()  -> ToolCallResultMsg;

    """Return the string representation of the tool call."""
    def __str__()  -> str;

    """Check if the tool is a finish tool."""
    def is_finish_call()  -> bool;

    """Get the output from the finish tool call."""
    def get_output()  -> object;
}

"""Mock tool call for testing purposes."""
obj MockToolCall {
    has tool: Callable;
    has args: dict;

    """Convert the mock tool call to a ToolCall."""
    def to_tool_call()  -> ToolCall;
}

"""Result of the completion from the LLM."""
obj CompletionResult {
    has output: object;
    has tool_calls: list[ToolCall];
}

# -----------------------------------------------------------------------------
# Media content types
# -----------------------------------------------------------------------------
"""Base class for message content."""
obj Media {
    """Convert the content to a dictionary."""
    def to_dict()  -> list[dict];
}

"""Class representing text content in a message."""
obj Text(Media) {
    has text: str;

    """Convert the text content to a dictionary."""
    def to_dict()  -> list[dict];
}

"""Class representing an image."""
obj Image(Media) {
    has url:
        (
            "str | bytes | bytearray | memoryview | BytesIO | IO[bytes] | "
            "os.PathLike[str] | os.PathLike[bytes] | PILImageCls"
        );  # type: ignore[name-defined]

    has mime_type: str | None = None;

    """Normalize input into a data URL or leave remote/data URLs as-is.

    Supported inputs:
    - HTTP(S)/GS URLs (left as-is)
    - Data URLs (data:...)
    - Local file paths (opened and encoded to data URL)
    - Bytes / bytearray / memoryview
    - File-like objects (BytesIO or any IO[bytes])
    - os.PathLike
    - PIL.Image.Image instances
    """
    def postinit()  -> None;

    """Map a PIL format name to a MIME type with sensible fallbacks."""
    def _format_to_mime(fmt: str | None) -> str;

    def _data_url_from_bytes(data: bytes, fmt: str | None) -> str;
    """Convert the image to a dictionary."""
    def to_dict()  -> list[dict];
}

# Ref: https://cookbook.openai.com/examples/gpt_with_vision_for_video_understanding
"""Class representing a video."""
obj Video(Media) {
    has path: str;
    has fps: int = 1;
    has _base64frames: list[str] | None = None;

    """Post-initialization to ensure the path is a string."""
    def postinit()  -> None;

    """Load video frames as base64-encoded images."""
    def load_frames()  -> None;

    """Convert the video to a dictionary."""
    def to_dict()  -> list[dict];
}
