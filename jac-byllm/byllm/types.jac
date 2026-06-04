"""Type definitions for LLM interactions.

This module defines the types used in the LLM interactions, including messages,
tools, and tool calls. It provides a structured way to represent messages,
tool calls, and tools that can be used in LLM requests and responses.
"""
import base64;
import logging;
import mimetypes;
import os;
import from contextlib { suppress }

glob logger: logging.Logger = logging.getLogger(__name__);
import from enum { StrEnum }
import from io { BytesIO }
import from typing { Callable, TypeAlias, get_type_hints }

import from PIL.Image { Image as PILImageCls }
import from PIL.Image { open as open_image }

import from litellm.types.utils { Message as LiteLLMMessage }
import from pydantic { TypeAdapter }
import from .schema { tool_to_schema }
import from byllm.exceptions { ByLLMError, FinishToolError, UnknownToolError }

import from jaclang.jac0core.mtp { Info }
import from byllm.mcp { McpTool }

# The message can be a jaclang defined message or what ever the llm
# returned object that was feed back to the llm as it was given (dict).
glob MessageType: TypeAlias = 'Message | LiteLLMMessage';

"""Enum for message roles in LLM interactions."""
enum MessageRole(StrEnum) {
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
    static def from_dict(d: dict) -> Message | LiteLLMMessage | dict;
}

"""Result of a tool call in LLM interactions."""
obj ToolCallResultMsg(Message) {
    has tool_call_id: str,
        name: str,
        role: MessageRole by postinit;

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
        params_desc: dict[(str, str)] = None,
        info: Info = None,
        serialize: bool = False,
        timeout_sec: float | None = None;

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
        tool: Tool | McpTool,
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
        tool_calls: list[ToolCall],
        usage: dict = {};
}

"""Unified event type for streaming output from by llm() calls.

Yielded by invoke() when logging=True is set in call_params.
All intermediate steps (thoughts, tool calls, results) and final
answer chunks share this single type.
"""
obj StreamEvent {
    has event_type: str,
        data: dict;
}

"""Control action returned by on_iteration callback."""
enum IterationAction(StrEnum) {
    CONTINUE = "continue",
    ABORT = "abort",
    ABORT_WITH_SUMMARY = "abort_with_summary"
}

"""Loop state snapshot passed to on_iteration callback."""
obj IterationContext {
    has iteration: int,
        messages: list,
        last_tool: str,
        last_result: str,
        total_tokens: int;
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


"""Serialize message content into provider content blocks.

Element shapes accepted: dict (already-serialized, passed through),
`(media, semstring)` tuple (semstring emitted as a text prelude),
and Media (via `to_dict()`).
"""
def serialize_media_content(content: list) -> list[dict] {
    blocks: list = [];
    for item in content {
        if isinstance(item, dict) {
            blocks.append(item);
            continue;
        }
        semstring = "";
        if isinstance(item, tuple) {
            semstring = item[1] or "";
            item = item[0];
        }
        if semstring {
            blocks.append({"type": "text", "text": semstring});
        }
        blocks.extend(item.to_dict());
    }
    return blocks;
}


"""Normalize a tool's return value into Message-compatible content.

str → str (common case).  Media → `[Media]`.  `list[Media]` → unchanged.
Anything else is stringified for back-compat with tools that return
dicts, ints, etc.
"""
def normalize_tool_result(value: any) -> str | list {
    if isinstance(value, str) {
        return value;
    }
    if isinstance(value, Media) {
        return [value];
    }
    if (
        isinstance(value, list)
        and value
        and all(isinstance(elem, Media) for elem in value)
    ) {
        return value;
    }
    return str(value);
}


"""Build a length-bounded printable string from message content.

Stream events and logging consumers expect `result` to be a string.
Multimodal content (e.g. a screenshot returned by a tool) would otherwise
leak ~30KB of base64 into every observability surface.
"""
def content_preview(content: any, max_len: int) -> str {
    if isinstance(content, str) {
        return content[:max_len];
    }
    if not isinstance(content, list) {
        return str(content)[:max_len];
    }
    parts: list = [];
    for item in content {
        if isinstance(item, str) {
            parts.append(item);
        } elif isinstance(item, Text) {
            parts.append(item.text);
        } else {
            kind = type(item).__name__.lower();
            parts.append(f"[{kind}]");
        }
    }
    return " ".join(parts)[:max_len];
}


"""Move tool-result images into a trailing user message; images across consecutive tool messages batch into ONE message."""
def reroute_tool_images_to_user_message(messages: list) -> list {
    # Common case: no tool images → return the input untouched (no allocations).
    if not any(_tool_msg_has_image(m) for m in messages) {
        return messages;
    }

    out: list = [];
    pending: list = [];  # image blocks buffered until the tool-result run ends

    for msg in messages {
        if _tool_msg_has_image(msg) {
            (stripped, images) = _split_tool_msg_images(msg);
            out.append(stripped);
            name = msg.get("name", "tool");
            call_id = msg.get("tool_call_id", "");
            pending.append(
                {"type": "text", "text": f"[Tool result for {name} (id {call_id})]:"}
            );
            pending.extend(images);
        } elif _is_tool_msg(msg) {
            # Text-only tool - still inside the run; can't flush yet (Anthropic alternation).
            out.append(msg);
        } else {
            if pending {
                out.append({"role": "user", "content": pending});
                pending = [];
            }
            out.append(msg);
        }
    }
    if pending {
        out.append({"role": "user", "content": pending});
    }
    return out;
}


def _is_tool_msg(msg: object) -> bool {
    return isinstance(msg, dict) and msg.get("role") == "tool";
}


def _tool_msg_has_image(msg: object) -> bool {
    if not _is_tool_msg(msg) {
        return False;
    }
    content = msg.get("content");
    if not isinstance(content, list) {
        return False;
    }
    for block in content {
        if isinstance(block, dict) and block.get("type") in ("image_url", "image") {
            return True;
        }
    }
    return False;
}


"""Split a tool message into (stripped_msg, image_blocks); no images → (msg, [])."""
def _split_tool_msg_images(msg: dict) -> tuple {
    content = msg.get("content");
    if not isinstance(content, list) {
        return (msg, []);
    }
    text_blocks: list = [];
    image_blocks: list = [];
    for block in content {
        if isinstance(block, dict) and block.get("type") in ("image_url", "image") {
            image_blocks.append(block);
        } else {
            text_blocks.append(block);
        }
    }
    if not image_blocks {
        return (msg, []);
    }
    text_only = all(
        isinstance(b, dict) and b.get("type") == "text" for b in text_blocks
    );
    if text_only {
        stripped_content = " ".join(b.get("text", "") for b in text_blocks).strip();
        if not stripped_content {
            stripped_content = "(image attached in following user message)";
        }
    } else {
        stripped_content = text_blocks;
    }
    return ({** msg, "content": stripped_content}, image_blocks);
}
