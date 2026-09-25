import inspect;
import json;

import from types { MethodType }
import from typing { get_type_hints }

obj MTIR {
    has caller: Callable,
        args: dict[(int | str, object)],
        call_params: dict[(str, object)],
        ir_info: (Info | None);

    has runtime: MTRuntime { getter; }
}

obj MTRuntime {
    has messages: list[MessageType],
        resp_type: type | None,
        stream: bool,
        tools: list[Tool | McpTool],
        call_params: dict[(str, object)],
        mtir: MTIR | None = None,
        _scaffolding_ids: list[int] = [],
        _conversation_list: (list[any] | None) = None,
        _final_output: object = None,
        _has_final_output: bool = False,
        _stream_reset_count: int = 0,
        _tool_arg_deltas: list[dict[str, any]] = [],
        _usage_history: list[dict[str, any]] = [],
        _call_kind: str = "react_iteration",
        _invocation_id: str = "",
        _parent_invocation_id: str | None = None;

    static def factory(mtir: MTIR) -> MTRuntime;
    def add_message(message: MessageType) -> None;
    def add_scaffolding_message(message: MessageType) -> None;
    def get_msg_list -> list[dict[(str, object)] | LiteLLMMessage];
    def get_history_for_persist -> list[MessageType];
    def write_back_conversation -> None;
    def parse_response(response: str) -> any;
    def get_tool(tool_name: str) -> Tool | McpTool | None;
    def get_tool_list -> list[dict[str, any]];
    def get_output_schema -> dict[str, any] | None;
    def get_typed_output_schema -> dict[str, any] | None;
}
