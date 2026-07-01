"""MTRuntime (Meaning Typed Intermediate Representation) module for JacLang runtime library."""
import inspect;
import json;
import from jaclang.jac0core.mtp { Info, MethodInfo, FunctionInfo }
import from types { MethodType }
import from typing { Callable, get_type_hints }
import from jaclang.byllm.schema { json_to_instance, type_to_schema }
import from jaclang.byllm.exceptions { ConfigurationError, OutputConversionError }
import from jaclang.byllm.config_loader { get_byllm_config }
import from jaclang.byllm.types {
    LiteLLMMessage,
    Media,
    Message,
    MessageRole,
    MessageType,
    Text,
    Tool,
    ToolCallResultMsg
}
import from jaclang.byllm.mcp { McpTool }

"""Intermediate representation for LLM function calls.

Captures the callable, its arguments, and call parameters to construct
an MTRuntime instance on demand via the runtime property.
"""
obj MTIR {
    has caller: Callable,
        args: dict[(int | str, object)],
        call_params: dict[(str, object)],
        ir_info: Info;

    has runtime: MTRuntime { getter; }
}

"""Runtime context for LLM interactions.

Manages the message history, tools, response type, and streaming state
for a single LLM invocation. Created via the factory method from an MTIR.
"""
obj MTRuntime {
    has messages: list[MessageType],
        resp_type: type | None,
        stream: bool,
        tools: list[Tool | McpTool],
        call_params: dict[(str, object)],
        mtir: MTIR | None = None,
        # IDs of byllm-injected messages excluded from the persisted view.
        _scaffolding_ids: list[int] = [],
        # Caller's list bound via `by llm(conversation=<list>)`, written
        # back in place after the ReAct loop. None when not conversational.
        _conversation_list: object = None,
        # Structured final value captured during a streamed ReAct loop so a
        # handler-driven invoke can return the parsed result after the event
        # stream is fully consumed.
        _final_output: object = None,
        _has_final_output: bool = False,
        # Bumped when a transient-error retry resets partial stream output;
        # consumers watch it to emit `stream_reset` and discard shown tokens.
        _stream_reset_count: int = 0;

    static def factory(mtir: MTIR) -> MTRuntime;
    def add_message(message: MessageType) -> None;
    def add_scaffolding_message(message: MessageType) -> None;
    def get_msg_list -> list[dict[(str, object)] | LiteLLMMessage];
    def get_history_for_persist -> list[MessageType];
    def write_back_conversation -> None;
    def parse_response(response: str) -> object;
    def get_tool(tool_name: str) -> Tool | McpTool | None;
    def get_tool_list -> list[dict];
    def get_output_schema -> dict | None;
    def get_typed_output_schema -> dict | None;
}
