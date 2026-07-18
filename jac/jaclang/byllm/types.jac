import base64;
import logging;
import mimetypes;
import os;
import from contextlib { suppress }

glob logger: logging.Logger = logging.getLogger(__name__);
import from enum { StrEnum }
import from io { BytesIO }
import from typing { Callable, TypeAlias, get_type_hints }

import from jaclang.byllm._optdeps.pillow { PILImageCls, open_image }
import from jaclang.byllm._optdeps.litellm { LiteLLMMessage }
import from jaclang.byllm._optdeps.pydantic { TypeAdapter }
import from .schema { tool_to_schema }
import from jaclang.byllm.exceptions { ByLLMError, FinishToolError }

import from jaclang.jac0core.mtp { Info }
import from jaclang.byllm.mcp { McpTool }

glob MessageType: TypeAlias = 'Message | LiteLLMMessage';

enum MessageRole(StrEnum) {
    SYSTEM = "system",
    USER = "user",
    ASSISTANT = "assistant",
    TOOL = "tool"
}

obj Message {
    has role: MessageRole,
        content: str | list[Media];

    def to_dict -> dict[str, object];
    static def from_dict(d: dict) -> Message | LiteLLMMessage | dict;
}

obj ToolCallResultMsg(Message) {
    has tool_call_id: str,
        name: str,
        role: MessageRole postinit;

    def postinit -> None;
    def to_dict -> dict[str, object];
}

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

obj ToolCall {
    has call_id: str,
        tool: Tool | McpTool,
        args: dict;

    def __call__ -> ToolCallResultMsg;
    def __str__ -> str;
    def is_finish_call -> bool;
    def get_output -> object;
}

obj MockToolCall {
    has tool: Callable,
        args: dict;

    def to_tool_call -> ToolCall;
}

obj MockRawResponse {
    has content: str;
}

obj MockError {
    has error: object;
}

obj CompletionResult {
    has output: object,
        tool_calls: list[ToolCall],
        usage: dict = {};
}

obj StreamEvent {
    has event_type: str,
        data: dict;
}

enum IterationAction(StrEnum) {
    CONTINUE = "continue",
    ABORT = "abort",
    ABORT_WITH_SUMMARY = "abort_with_summary"
}

obj IterationContext {
    has iteration: int,
        messages: list,
        last_tool: str,
        last_result: str,
        total_tokens: int;
}

obj Media {
    def to_dict -> list[dict];
}

obj Text(Media) {
    has text: str;

    def to_dict -> list[dict];
}

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

obj Video(Media) {
    has path: str,
        fps: int = 1,
        _base64frames: list[str] | None = None;

    def postinit -> None;
    def load_frames -> None;
    def to_dict -> list[dict];
}


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


def reroute_tool_images_to_user_message(messages: list) -> list {
    if not any(_tool_msg_has_image(m) for m in messages) {
        return messages;
    }

    out: list = [];
    pending: list = [];

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
