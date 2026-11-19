import copy;
import functools;
import json;
import os;
import typing;
import from collections.abc { Iterator as AbcIterator }

enum IterationAction: str { CONTINUE = "continue", ABORT_WITH_SUMMARY = "abort", }

enum PartKind: str {
    TEXT = "text",
    TOOL_CALL = "tool_use",
    TOOL_RESULT = "tool_result",
}

obj Part {
    has kind: PartKind,
        text: str = "",
        id: str = "",
        name: str = "",
        input: str = "",
        failed: bool = False;
}

obj Message {
    has role: str,
        parts: list[Part] = [];
}

obj IterationContext {
    has iteration: int = 0,
        usage: ByUsage = ByUsage();
}

glob DEFAULT_MODEL: str = "claude-sonnet-5-5",
     _usage_hooks: list[Callable[[ByUsage], None]] = [],
     _models: dict[str, NeoModel] = {};

def on_usage(f: Callable[[ByUsage], None]);

def model_name -> str;

def usage_of(record: dict[str, any]) -> ByUsage;

def _report_usage(payload: dict[str, any]) -> None;

def _the_model -> NeoModel;

def _api_message(m: Message) -> list[dict[str, any]];

def _kept_message(d: dict[str, any]) -> Message;

def _text_of(content: any) -> str;

class ConversationView(list) {
    def init(self: ConversationView, history: list[Message]);
    def __setitem__(self: ConversationView, key: any, value: any);
}

def _loop_action(action: any) -> any;

def _guard(f: Callable[[IterationContext], IterationAction]) -> Callable[[any], any];

def _streams_events(caller: any) -> bool;

def _as_text_caller(caller: any) -> any;

obj NeoModel(Model) {
    has plugin_args: list[any] = [];

    override def __call__(**kwargs: object) -> NeoModel;
    override def invoke(mt_run: any) -> any;
    override async def ainvoke(mt_run: any) -> any;
    def _prepared(mt_run: any) -> any;
    def _drop_plugin_args(mtir: MTIR) -> None;
    def _events(mtir: MTIR) -> Iterator[ByEvent];
}

def _stream_marker(event: any);

def llm(
    max_tokens: int = 4000,
    reasoning_effort: str = "",
    max_output_retries: int = 1,
    timeout: int = 60,
    num_retries: int = 0,
    tools: list[any] = [],
    max_react_iterations: int = 8,
    on_iteration: any = None,
    system_prompt: str = "",
    conversation: list[Message] | None = None,
    parallelize: bool = False,
    select: any = 1,
    intent: str = ""
) -> any;
