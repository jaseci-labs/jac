"""The contract of the `llm` abstraction: `Model`, the interface of the plugin
that speaks to a language model, and what crosses it: one request in, the
reply's events out.

Everything that is the same for every model is the program's, above the
plugin: the instructions made of a function's `sem`s, the arguments as JSON,
the rounds of tool calls, a reply that does not fit its type sent back to be
corrected, conversations, and a walker's choice."""

import from common.contract { Host }

"""How hard a model works at an answer, where its provider has such a
setting: the provider's own choice, or one of three levels, which each
plugin maps to what its provider calls them."""
enum Effort {
    DEFAULT = "",
    LOW = "low",
    MEDIUM = "medium",
    HIGH = "high",
}

"""What a part of a message is."""
enum PartKind {
    TEXT = "text",
    TOOL_CALL = "tool_use",
    TOOL_RESULT = "tool_result",
    KEPT = "kept",
}

"""One part of a message of a conversation:
- TEXT: `text`;
- TOOL_CALL: the model calls tool `name` with `input`, its arguments as the
  JSON text the model wrote, the call named `id`;
- TOOL_RESULT: what the call named `id` gave, `text`; `failed` when the tool
  raised or there was none;
- KEPT: something of the provider's own that it reads back as it wrote it
  while one call is answered (`text`, in its own form), and nothing else
  reads: it is in no conversation a program keeps."""
obj Part {
    has kind: PartKind,
        text: str = "",
        id: str = "",
        name: str = "",
        input: str = "",
        failed: bool = False;
}

"""A message of a conversation: who said it (`user` or `assistant`) and its
parts. A conversation is a list of them, which a program may keep: in a
node's field, across a crossing."""
obj Message {
    has role: str,
        parts: list[Part] = [];
}

"""A tool a model may call: its name, what it is for, and the JSON schema of
its arguments."""
obj ModelTool {
    has name: str,
        doc: str,
        schema: dict[str, any];
}

"""One request of a model: the instructions (`system`), the messages so far,
the tools it may call (none of them once `answer_now`), the JSON schema its
answer must fit (None for an answer that is text), the most tokens it may
answer in, how hard it works, and whether its answer is wanted as it is
written (`live`)."""
obj ModelRequest {
    has system: str,
        messages: list[Message],
        tools: list[ModelTool] = [],
        result_schema: dict[str, any] | None = None,
        max_tokens: int = 4000,
        effort: Effort = Effort.DEFAULT,
        answer_now: bool = False,
        live: bool = False;
}

"""Why a model stopped."""
enum Stop {
    END = "end",
    TOOLS = "tools",
    MAX_TOKENS = "max_tokens",
    REFUSED = "refused",
}

"""What a plugin used to answer: the requests it made and, for a model, the
tokens they took and the seconds they waited."""
obj ByUsage {
    has requests: int = 0,
        input_tokens: int = 0,
        output_tokens: int = 0,
        cache_read_tokens: int = 0,
        cache_write_tokens: int = 0,
        seconds: float = 0.0,
        model: str = "";

    """This with `more` added to it."""
    def add(more: ByUsage) {
        self.requests += more.requests;
        self.input_tokens += more.input_tokens;
        self.output_tokens += more.output_tokens;
        self.cache_read_tokens += more.cache_read_tokens;
        self.cache_write_tokens += more.cache_write_tokens;
        self.seconds += more.seconds;
        if more.model != "" {
            self.model = more.model;
        }
    }
}

"""What an event of a streamed call says."""
enum ByEventKind {
    TEXT = "text",
    TOOL_CALL = "tool_call",
    TOOL_RESULT = "tool_result",
    USAGE = "usage",
    DONE = "done",
}

"""One thing a plugin says as it works on a call it streams:
- TEXT: `text`, the next piece of its answer;
- TOOL_CALL: it calls tool `tool` with `args`, the call named `call_id`;
- TOOL_RESULT: what that call gave, `result`;
- USAGE: `usage`, what one request took;
- DONE: the call is answered: `text` is the whole answer."""
obj ByEvent {
    has kind: ByEventKind,
        text: str = "",
        tool: str = "",
        call_id: str = "",
        args: dict[str, any] = {},
        result: str = "",
        usage: ByUsage | None = None,
        # (A typed call's result, and a model's reply: for what asked.)
        value: any = None;
}

"""A plugin couldn't produce the declared type."""
obj ByError(Exception) {}

"""A model's reply to one request: its message (its text, the tools it
calls, and what its provider keeps), why it stopped, and what the request
used. The text of a reply asked to fit a schema is the JSON value itself."""
obj ModelReply {
    has message: Message,
        stop: Stop = Stop.END,
        usage: ByUsage = ByUsage();
}

"""What speaks to a model: the interface of the `llm` abstraction's plugins.
`open` is the first thing asked of it, given the program it runs in. `ask`
makes one request and gives its events: each piece of the answer's text as
a TEXT event, for a `live` request, and last a DONE whose `value` is the
`ModelReply`. ByError for a request the provider refuses or can't be
reached with."""
obj Model {
    def open(host: dyn Host) abst;
    def ask(request: ModelRequest) -> Iterator[ByEvent] abst;
}
