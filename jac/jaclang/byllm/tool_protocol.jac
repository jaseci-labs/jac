import json;
import re;
import uuid;
import from types { SimpleNamespace }

glob _TOOL_PROTOCOL_HEADER = "# Calling tools";

def _render_tool(tool: object) -> str;


def format_tools_for_prompt(tools: list[dict[str, any]]) -> str;


def attach_tool_hint(
    messages: list[dict[str, any]], block: str
) -> list[dict[str, any]];


def response_field(val: object, key: str) -> object;


def _tool_call_name_args(tc: object) -> tuple[str, dict[str, any]];


def linearize_tool_messages(messages: list[dict[str, any]]) -> list[dict[str, any]];


def inject_tool_hint(params: dict[str, any]) -> dict[str, any];


def _merge_stop(existing: object, extra: list[str]) -> list[str];

def _balanced(text: str, start: int, open_ch: str, close_ch: str) -> str | None;


def _call_fields(cobj: object) -> dict[str, any] | None;


def _extract_json_call(content: str, tool_names: list[str]) -> dict[str, any] | None;


def _split_top_level(text: str) -> list[str];


def _parse_value(token: str) -> object;


def _parse_kwargs(argstr: str) -> dict[str, any];


def _extract_paren_call(content: str, tool_names: list[str]) -> dict[str, any] | None;


def _extract_first_tool_call(
    content: str, tool_names: list[str]
) -> dict[str, any] | None;


def coerce_message_dict(message: object) -> dict[str, any];


def recover_tool_calls(
    message: object, tool_names: list[str] | None = None
) -> dict[str, any];
