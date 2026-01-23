"""MTRuntime (Meaning Typed Intermediate Representation) module for JacLang runtime library."""
import inspect;
import json;
import from types { MethodType }
import from typing { Callable, get_type_hints }
import from byllm.schema { json_to_instance, type_to_schema }
import from byllm.config_loader { get_byllm_config }
import from byllm.types {
    LiteLLMMessage,
    Media,
    Message,
    MessageRole,
    MessageType,
    Text,
    Tool
}

"""Intermediate representation for LLM function calls.

Captures the callable, its arguments, and call parameters to construct
an MTRuntime instance on demand via the runtime property.
"""
obj MTIR {
    has caller: Callable,
        args: dict[(int | str, object)],
        call_params: dict[(str, object)];

    @property
    def runtime -> MTRuntime {
        return MTRuntime.factory(self.caller, self.args, self.call_params);
    }
}

"""Runtime context for LLM interactions.

Manages the message history, tools, response type, and streaming state
for a single LLM invocation. Created via the factory method from an MTIR.
"""
obj MTRuntime {
    has messages: list[MessageType],
        resp_type: type | None,
        stream: bool,
        tools: list[Tool],
        call_params: dict[(str, object)];

    static def factory(
        caller: Callable,
        args: dict[(int | str, object)],
        call_params: dict[(str, object)]
    ) -> MTRuntime;

    def dispatch_params -> dict[str, object];
    def add_message(message: MessageType) -> None;
    def get_msg_list -> list[dict[(str, object)] | LiteLLMMessage];
    def parse_response(response: str) -> object;
    def get_tool(tool_name: str) -> Tool | None;
    def get_tool_list -> list[dict];
    def get_output_schema -> dict | None;
}
