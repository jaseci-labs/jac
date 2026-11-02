import base64;
import inspect;
import logging;
import mimetypes;
import os;
import from contextlib { suppress }

glob logger: logging.Logger = logging.getLogger(__name__);
import from enum { StrEnum }
import from io { BytesIO }
import from typing { IO, get_args, get_origin, get_type_hints }

type MessageType = Message | LiteLLMMessage | dict[str, object];

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
    static def from_dict(d: dict[str, any]) -> Message | dict[str, any];
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
        params_desc: (dict[str, str] | None) = None,
        info: (Info | None) = None,
        serialize: bool = False,
        timeout_sec: float | None = None;

    def postinit -> None;
    def __call__(*args: any, **kwargs: any) -> any;
    def get_name -> str;
    static def get_func_description(func: Callable) -> str;
    static def make_finish_tool(resp_type: type) -> Tool;
    def is_finish_tool -> bool;
    def get_json_schema -> dict[str, object];
    def parse_arguments(args_json: dict[str, any] | str) -> dict[str, any];
    def _parse_finish_arguments(
        args_json: dict[str, any], params: dict[str, any]
    ) -> dict[str, any];

    def _required_params(params: dict[str, any]) -> list[str];
}

obj ToolCall {
    has call_id: str,
        tool: Tool | McpTool,
        args: dict[str, any];

    def __call__ -> ToolCallResultMsg;
    def __str__ -> str;
    def is_finish_call -> bool;
    def get_output -> object;
}

obj MockToolCall {
    has tool: Callable | str,
        args: dict[str, any] | str = {},
        call_id: str = "";

    def to_tool_call -> ToolCall;
}

obj MockRawResponse {
    has content: str = "",
        tool_calls: list[MockToolCall] = [],
        usage: dict[str, any] | None = None,
        finish_reason: str = "",
        model: str = "",
        unnamed_fragments: bool = False,
        fields: dict[str, any] = {};
}

obj MockError {
    has error: Exception,
        content: str = "",
        after: int = 0,
        reply: object = None;
}

obj CompletionResult {
    has output: object,
        tool_calls: list[ToolCall],
        usage: dict[str, any] = {},
        finish_reason: str = "";
}

obj StreamEvent {
    has event_type: str,
        data: dict[str, any];
}

enum IterationAction(StrEnum) {
    CONTINUE = "continue",
    ABORT = "abort",
    ABORT_WITH_SUMMARY = "abort_with_summary"
}

obj IterationContext {
    has iteration: int,
        messages: list[MessageType],
        last_tool: str,
        last_result: str,
        total_tokens: int,
        total_cost: float = 0.0;
}

obj Media {
    def to_dict -> list[dict[str, any]];
}

obj Text(Media) {
    has text: str;

    def to_dict -> list[dict[str, any]];
}

obj Image(Media) {
    has url:
        (
            str
            | bytes
            | bytearray
            | memoryview
            | BytesIO
            | IO[bytes]
            | os.PathLike[str]
            | os.PathLike[bytes]
            | PILImageCls
        ),
        mime_type: str | None = None;

    def postinit -> None;
    def _format_to_mime(fmt: str | None) -> str;
    def _data_url_from_bytes(data: bytes, fmt: str | None) -> str;
    def to_dict -> list[dict[str, any]];
}

obj Video(Media) {
    has path: str,
        fps: int = 1,
        _base64frames: list[str] | None = None;

    def postinit -> None;
    def load_frames -> None;
    def to_dict -> list[dict[str, any]];
}

obj Document(Media) {
    has source: str | os.PathLike[str] | bytes | bytearray | memoryview,
        filename: str | None = None,
        _data_url: str = "";

    def postinit -> None;
    def to_dict -> list[dict[str, any]];
}


def image_resp_kind(resp_type: type | None) -> str;


def serialize_media_content(content: list[any]) -> list[dict[str, any]];


def as_media_list(value: any) -> list[Media] | None;


def normalize_tool_result(value: any) -> str | list[Media];


def content_preview(content: any, max_len: int) -> str;


glob TOOL_MEDIA_BLOCKS: tuple[str, ...] = ("image_url", "image", "file");

def reroute_tool_images_to_user_message(
    messages: list[dict[str, object] | LiteLLMMessage]
) -> list[dict[str, object] | LiteLLMMessage];


def _is_tool_msg(msg: object) -> bool;


def _tool_msg_has_image(msg: object) -> bool;


def _split_tool_msg_images(
    msg: dict[str, any]
) -> tuple[dict[str, any], list[dict[str, any]]];


def response_dict(value: object) -> dict[str, any];
