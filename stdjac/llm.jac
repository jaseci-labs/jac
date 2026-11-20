"""`by llm(...)`: a function's result asked of a language model.

`llm` is the abstraction: source says a model answers, and never which. What
speaks to a model is the project's `llm` plugin, which conforms to `Model`:
one request in, the reply's events out. Everything that is the same for
every model is here: the instructions made of the function's `sem`s, the
arguments as JSON, the rounds of tool calls, a reply that does not fit its
type sent back to be corrected, conversations, and a walker's choice.

A function declared to give `Iterator[ByEvent]` is answered as the model
goes: its answer is text, and each piece of it, each tool call and each
tool's result is an event. `visit ... by llm(...)` asks it which of a
walker's ways to take."""

import json;
import time;

enum IterationAction {
    CONTINUE = "continue",
    ABORT_WITH_SUMMARY = "abort",
}

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

"""A model's reply to one request: its message (its text, the tools it
calls, and what its provider keeps), why it stopped, and what the request
used. The text of a reply asked to fit a schema is the JSON value itself."""
obj ModelReply {
    has message: Message,
        stop: Stop = Stop.END,
        usage: ByUsage = ByUsage();
}

"""What speaks to a model: the interface of the `llm` abstraction's plugins.
`ask` makes one request and gives its events: each piece of the answer's
text as a TEXT event, for a `live` request, and last a DONE whose `value` is
the `ModelReply`. ByError for a request the provider refuses or can't be
reached with."""
obj Model {
    def ask(request: ModelRequest) -> Iterator[ByEvent] abst;
}

glob _model: list[dyn Model] = [];

"""The project's model."""
def model -> dyn Model {
    if len(_model) == 0 {
        m: dyn Model = bound("llm");
        _model.append(m);
    }
    return _model[0];
}

"""What `on_iteration` is told after each round of tool calls: how many
rounds the call has made, and what its requests have used so far."""
obj IterationContext {
    has iteration: int = 0,
        usage: ByUsage = ByUsage();
}

"""What `on_usage` was given: each is told what every request used."""
glob _usage_hooks: list[Callable[[ByUsage], None]] = [];

"""Call `f` with what each request of a model used, after the request, on the
thread that made it: a program's own account of what its `by` calls cost."""
def on_usage(f: Callable[[ByUsage], None]) {
    _usage_hooks.append(f);
}

obj LLM(By, ByStreams, ByChooser) {
    has max_tokens: int = 4000,
        effort: Effort = Effort.DEFAULT,
        max_react_iterations: int = 8,
        max_output_retries: int = 1,
        on_iteration: any = None,
        system_prompt: str = "",
        conversation: list[Message] | None = None,
        parallelize: bool = False,
        select: any = 1,
        intent: str = "";

    def invoke(call: ByCall) -> any;
    def stream(call: ByCall) -> Iterator[ByEvent];
    def choose(choice: ByChoice) -> list[int];

    """The call's events as the model answers it: `live` asks for its reply
    as it is written, and takes the answer as text. The last event is DONE:
    its `value` a typed call's result, its `text` a live one's answer."""
    def answer(call: ByCall, live: bool) -> Iterator[ByEvent];

    """What the tool call `u` gave, as the part that answers it."""
    def run_tool(named: dict[str, ByTool], u: Part) -> Part;

    """What one round's tool calls gave, in their order: each on a thread of
    its own when it was told to `parallelize`."""
    def run_tools(named: dict[str, ByTool], uses: list[Part]) -> list[Part];
}

"""`by llm(max_tokens=..., tools=[...])`. The compiler reads `tools` from the
call, and each arrives in the ByCall with its schema (stdjac.by's by_tool).

- `max_tokens` is the most tokens one reply may have, and `effort` how hard
  the model works at it.
- `system_prompt` is said to the model before the function's `sem`.
- `conversation` is the turns before this one, a list of `Message`: the call
  is the next turn, and its messages are added to the list when it has
  answered, so the caller that keeps the list keeps the conversation.
- `parallelize` runs the tool calls of one round at once.
- `select` and `intent` are for `visit ... by llm(...)`: how many ways to take
  (a number, or a `(least, most)` pair) and what the choice is for.

Which model answers, where it is and how long it is waited for are not said
here: they are the settings of the project's `llm` plugin."""
def llm(
    max_tokens: int = 4000,
    effort: Effort = Effort.DEFAULT,
    max_output_retries: int = 1,
    tools: list[any] = [],
    max_react_iterations: int = 8,
    on_iteration: any = None,
    system_prompt: str = "",
    conversation: list[Message] | None = None,
    parallelize: bool = False,
    select: any = 1,
    intent: str = "",
) -> LLM {
    return LLM(
        max_tokens=max_tokens,
        effort=effort,
        max_react_iterations=max_react_iterations,
        max_output_retries=max_output_retries,
        on_iteration=on_iteration,
        system_prompt=system_prompt,
        conversation=conversation,
        parallelize=parallelize,
        select=select,
        intent=intent,
    );
}

"""`m` as a program keeps it in a conversation: without what only its
provider reads."""
def kept_message(m: Message) -> Message {
    return Message(role=m.role, parts=[p for p in m.parts if p.kind != PartKind.KEPT]);
}

impl LLM.answer(call: ByCall, live: bool) -> Iterator[ByEvent] {
    system = call.doc;
    for k in call.arg_docs.keys() {
        system += "\n" + k + ": " + call.arg_docs[k];
    }
    if self.system_prompt != "" {
        system = self.system_prompt + "\n\n" + system;
    }
    system += "\n\nThe user message holds the arguments, as JSON.";
    # This turn's messages, after the conversation's: kept by the caller's
    # list once the call has answered.
    kept = self.conversation;
    before: list[Message] = list(kept) if kept is not None else [];
    turn: list[Message] = [
        Message(role="user", parts=[Part(kind=PartKind.TEXT, text=json.dumps(call.args))]),
    ];
    tools: list[ModelTool] = [];
    named: dict[str, ByTool] = {};
    for t in call.tools {
        named[t.name] = t;
        tools.append(ModelTool(name=t.name, doc=t.doc, schema=t.schema));
    }
    asked = model();
    total = ByUsage();
    # Everything the model has said in this call, a round of tool calls'
    # words included: a live call's answer.
    whole = "";
    tries = 0;
    steps = 0;
    finish = False;
    while True {
        began = time.time();
        got: ModelReply | None = None;
        for event in asked.ask(
            ModelRequest(
                system=system,
                messages=before + turn,
                tools=tools,
                result_schema=None if live else call.result_schema,
                max_tokens=self.max_tokens,
                effort=self.effort,
                answer_now=finish,
                live=live,
            ),
        ) {
            if event.kind == ByEventKind.DONE {
                got = event.value;
            } elif live {
                yield event;
            }
        }
        if got is None {
            raise ByError(call.name + ": the model gave no reply");
        }
        reply: ModelReply = got;
        used = reply.usage;
        used.requests = 1;
        used.seconds = time.time() - began;
        total.add(used);
        for hook in _usage_hooks {
            hook(used);
        }
        yield ByEvent(kind=ByEventKind.USAGE, usage=used);
        if reply.stop == Stop.REFUSED {
            raise ByError(call.name + ": the model declined this request");
        }
        said = reply.message;
        text = "".join([p.text for p in said.parts if p.kind == PartKind.TEXT]);
        whole += text;
        uses = [p for p in said.parts if p.kind == PartKind.TOOL_CALL];
        if len(uses) > 0 {
            for u in uses {
                given: any = json.loads(u.input) if u.input != "" else {};
                yield ByEvent(
                    kind=ByEventKind.TOOL_CALL,
                    tool=u.name,
                    call_id=u.id,
                    args=given if isinstance(given, dict) else {},
                );
            }
            results = self.run_tools(named, uses);
            for (u, r) in zip(uses, results) {
                yield ByEvent(
                    kind=ByEventKind.TOOL_RESULT, tool=u.name, call_id=u.id, result=r.text
                );
            }
            turn.append(said);
            turn.append(Message(role="user", parts=results));
            steps += 1;
            if steps >= self.max_react_iterations {
                finish = True;
            } elif self.on_iteration is not None {
                check: Callable[[IterationContext], IterationAction] = self.on_iteration;
                finish = check(IterationContext(iteration=steps, usage=total))
                    == IterationAction.ABORT_WITH_SUMMARY;
            }
            continue;
        }
        text = text.strip();
        if live {
            turn.append(said);
            if kept is not None {
                kept.extend([kept_message(m) for m in turn]);
            }
            yield ByEvent(kind=ByEventKind.DONE, text=whole);
            return;
        }
        if text.startswith("```") {
            text = text.strip("`").removeprefix("json").strip();
        }
        try {
            if reply.stop == Stop.MAX_TOKENS {
                raise ValueError("the reply ran past max_tokens");
            }
            value: any = json.loads(text);
            result: any = call.decode(value) if call.decode is not None else value;
            turn.append(said);
            if kept is not None {
                kept.extend([kept_message(m) for m in turn]);
            }
            yield ByEvent(kind=ByEventKind.DONE, text=text, value=result);
            return;
        } except Exception as e {
            tries += 1;
            if tries > self.max_output_retries {
                raise ByError(
                    call.name
                        + ": the model's reply doesn't fit its result ("
                        + str(e)
                        + "): "
                        + text[:300],
                );
            }
            turn.append(said);
            turn.append(
                Message(
                    role="user",
                    parts=[
                        Part(
                            kind=PartKind.TEXT,
                            text="That didn't fit: " + str(e) + ". Reply with only the JSON.",
                        ),
                    ],
                ),
            );
        }
    }
}

impl LLM.invoke(call: ByCall) -> any {
    for event in self.answer(call, False) {
        if event.kind == ByEventKind.DONE {
            return event.value;
        }
    }
    raise ByError(call.name + ": the model gave no answer");
}

impl LLM.stream(call: ByCall) -> Iterator[ByEvent] {
    return self.answer(call, True);
}

impl LLM.choose(choice: ByChoice) -> list[int] {
    least = 1;
    most = 1;
    if isinstance(self.select, int) {
        count: int = self.select;
        least = count;
        most = count;
    } elif isinstance(self.select, tuple) {
        bounds: tuple[int, int] = self.select;
        (least, most) = bounds;
    } else {
        raise ByError(
            choice.name + ": select is a number of ways, or a (least, most) pair of them"
        );
    }
    many = len(choice.options);
    most = min(most, many);
    least = min(least, most);
    if many == 0 or most <= 0 {
        return [];
    }
    said = "Choose which of the options a walker moves to next, by their numbers."
        + f" Choose at least {least} and at most {most} of them, the most useful first.";
    if self.intent != "" {
        said += "\nWhat the choice is for: " + self.intent;
    }
    picked: list[int] = self.invoke(
        ByCall(
            name=choice.name,
            doc=said,
            args={"walker": choice.asker, "at": choice.at, "options": choice.options},
            arg_docs={
                "walker": "The walker's own state.",
                "at": "The node the walker is at.",
                "options": "Where it may go: each option's number, the node there, and the edges that lead to it, each with what its type means.",
            },
            result_schema={"type": "array", "items": {"type": "integer"}},
            decode=None,
        ),
    );
    out: list[int] = [];
    for i in picked {
        if isinstance(i, int) and 0 <= i and i < many and i not in out and len(out) < most {
            out.append(i);
        }
    }
    return out;
}

impl LLM.run_tools(named: dict[str, ByTool], uses: list[Part]) -> list[Part] {
    if not self.parallelize or len(uses) < 2 {
        return [self.run_tool(named, u) for u in uses];
    }
    # Each a task: run at once, with the context variables and the caller
    # its maker has, as one run in turn would be.
    tasks = [flow self.run_tool(named, u) for u in uses];
    return [wait t for t in tasks];
}

impl LLM.run_tool(named: dict[str, ByTool], u: Part) -> Part {
    out = Part(kind=PartKind.TOOL_RESULT, id=u.id);
    if u.name not in named {
        out.text = "no such tool";
        out.failed = True;
        return out;
    }
    try {
        given: any = json.loads(u.input) if u.input != "" else {};
        r = named[u.name].call(given);
        out.text = r if isinstance(r, str) else json.dumps(r);
    } except Exception as e {
        out.text = "the tool failed: " + str(e);
        out.failed = True;
    }
    return out;
}
