---
description: Functions a language model (an LLM) or another value answers (def f(...) -> T by llm();), the tools that make one an agent, a by function that streams its answer, the By, ByStreams and ByChooser interfaces such a value conforms to, llm() and the plugin that speaks to a model, its conversations and usage, and sem strings that describe declarations to them.
keywords: by, sem, semantic string, llm, language model, LLM, AI, agent, tool use, By, ByCall, ByTool, ByError, ByStreams, ByEvent, ByEventKind, ByUsage, ByChooser, ByChoice, on_usage, IterationContext, ANTHROPIC_API_KEY, JAC_LLM_ADDRESS, Effort, Model, ModelRequest, ModelReply, anthropic, JAC_LLM_MODEL
grammar: sem_def, by_expr
---
# By and sem

A function declared with `by` in place of a body has its result computed by
the value it names, its **answerer**: `def triage(message: str) -> Ticket by llm();` asks a language
model for a `Ticket`. The compiler gives the answerer what it knows of the
function: its name, its arguments, the JSON schema of its result type and
the descriptions `sem` declarations attach to the function, its parameters
and the result's fields. The answerer's answer is decoded as the declared type
and checked, so the caller gets a `Ticket` or an exception, never text.

Two more forms hand work to an answerer. A `by` function declared to give
`Iterator[ByEvent]` is answered as the answerer goes, an event at a time
([below](#a-by-function-that-streams)). `visit <nodes> by <chooser>;` has a
answerer choose which of the nodes a walker goes to ([visit](visit.md#visit--by)).

## Syntax

```ebnf
sem_def ::= "sem" impl_target_name ("." impl_target_name)* "=" STRING+ ";"

by_expr ::= pipe ("by" by_expr)?
```

A `by` function is the `ability` production with `"by" expression` in place
of a block (see [Methods](methods.md)): `def name(params) -> T by e;`.

The `by` operator of an expression (`by_expr`) has its meaning in one
statement: `visit <nodes> by <chooser>;` ([visit](visit.md#visit--by)). In
any other expression it is E5090.

A `sem` names its target by a dotted path, as an [`impl`](impl.md) does,
and gives it a string; several adjacent strings are joined (`sem f = "One "
"sentence.";`). The statement ends with `;` (E0002) and the string follows
`=` (`sem x is "..."` is E0156).

| Target | Example |
|---|---|
| A function | `sem triage = "Turn a message into a ticket.";` |
| A function's parameter | `sem triage.message = "The message as written.";` |
| A class: an `obj`, `node`, `edge`, `walker` or `enum` | `sem Reviewer = "A reviewer of one repository.";` |
| An archetype's field | `sem Ticket.title = "A short title.";` |
| An enum's member | `sem Severity.CRITICAL = "Breaks production, loses data or leaks a secret.";` |
| A method | `sem Reviewer.read_file = "Read the start of a file.";` |
| A method's parameter | `sem Reviewer.read_file.path = "The file, from the repository's root.";` |

## What a `by` function does

`def f(a: A, b: B = d) -> R by e;` is a function whose body

1. evaluates `e`, which must give a value of a class conforming to the
   interface `By` (below), once per call. `e` is an expression of the
   module like any other: `llm` is built in, any other answerer is a
   name the module has, and a name it does not have is W2001;
2. encodes the arguments by their types, as `encode` (from `stdjac`) does,
   into a dict from parameter name to JSON value (an enum member by its name,
   an object as a dict of its fields). A parameter `e` hands the answerer whole
   is not among them ([below](#a-parameter-the-answerer-takes-whole));
3. calls that value's `invoke` with a `ByCall` holding the call's name, the
   function's `sem`, the arguments, the parameters' `sem`s, the JSON schema
   of `R` with each field's `sem` as its description, a decoder for `R`, and
   the tools;
4. returns what `invoke` returns, as an `R`.

The tools are what `e`'s `tools=` argument lists (`llm(tools=[lookup])`):
each arrives as a `ByTool` with its name, its `sem`, the JSON schema of its
parameters, and a function that calls it with arguments given as JSON and
gives its result as JSON. A tool is one of:

| Tool | Written | Called as |
|---|---|---|
| A function | `tools=[lookup]` | `lookup(...)` |
| A method of one of the `by` function's parameters | `tools=[r.read_file]`, `r` a parameter | `r.read_file(...)`, on the argument the call was given |

A method tool is described by the method's `sem` and its parameters'
(`sem Reviewer.read_file`, `sem Reviewer.read_file.path`), and is named for
the method (`read_file`). The parameter's type is one class (`r: Reviewer`):
with another type (`r: Reviewer | None`) the tool is E5090.

### A parameter the answerer takes whole

A parameter that `e` passes whole as a keyword argument
(`by llm(conversation=history)`, `history` a parameter) is the answerer's. It
is not among the call's arguments (`ByCall.args`), and its `sem` is not among
`arg_docs`: the answerer is given the value itself, the same object the caller
passed. A parameter used inside a larger expression (`tools=[r.read_file]`)
is still an argument.

Here `r` is an argument and the owner of a tool, and `notes` is the
answerer's, which adds to the caller's list:

```jac
import from stdjac { By, ByCall }

"""An answerer without a model: it calls its tool, and notes what
the tool gave."""
obj Canned(By) {
    has tools: list[any] = [],
        notes: list[str] = [];

    def invoke(call: ByCall) -> any {
        print("args:", call.args);
        print("arg docs:", call.arg_docs);
        tool = call.tools[0];
        print("tool:", tool.name, "|", tool.doc);
        print("schema:", tool.schema);
        self.notes.append(tool.call({"path": "a.py"}));
        return call.decode(self.notes[-1]);
    }
}

obj Reviewer {
    has repo: str;

    def read_file(path: str, lines: int = 3) -> str {
        return f"{self.repo}/{path}: {lines} lines";
    }
}

sem Reviewer = "A reviewer of one repository.";
sem Reviewer.repo = "Where the repository is.";
sem Reviewer.read_file = "Read the start of a file.";
sem Reviewer.read_file.path = "The file, from the repository's root.";

def review(r: Reviewer, path: str, notes: list[str]) -> str by Canned(
    tools=[r.read_file], notes=notes
);

sem review = "Review one file.";
sem review.r = "The reviewer.";
sem review.notes = "What was read.";

with entry {
    notes: list[str] = [];
    print(review(Reviewer(repo="/src"), "a.py", notes));
    print(notes);
}
```

```output
args: {'r': {'repo': '/src'}, 'path': 'a.py'}
arg docs: {'r': 'The reviewer.'}
tool: read_file | Read the start of a file.
schema: {'type': 'object', 'properties': {'path': {'type': 'string', 'description': "The file, from the repository's root."}, 'lines': {'type': 'integer'}}, 'required': ['path']}
/src/a.py: 3 lines
['/src/a.py: 3 lines']
```

### The result type

The result type is required, and must have a JSON schema: `int`, `float`,
`str`, `bool`, `None`, an enum (by its members' names), a `list` or `set`, a
`dict` with `str` keys, a union of one type and `None`, and an `obj`, `node`
or `struct` whose fields have one (a field without a default is required).
Another type (`any`, `bytes`, a `tuple`, a `walker`, a function value or a
type holding one) is refused at compile time, once, where the function is
declared. `Iterator[ByEvent]` is not a result's type: it asks for the answer
as a stream.

## A `by` function that streams

`def f(a: A) -> Iterator[ByEvent] by e;` asks the answerer for its answer as it
goes. `e` gives a value of a class conforming to `ByStreams` (below), whose
`stream` is called with the `ByCall` and gives the events. The call has no
result type: its answer is text, and the `ByCall` carries no `result_schema`
and no `decode`. The arguments, the `sem`s and the tools are as for any `by`
function.

The function returns the iterator at once, and the answerer works as the
caller reads it:

```jac
import from stdjac { ByCall, ByEvent, ByEventKind, ByStreams, ByUsage }

"""An answerer that answers as it goes, without a model: a word at a time."""
obj Echo(ByStreams) {
    def stream(call: ByCall) -> Iterator[ByEvent] {
        words = str(call.args["message"]).split();
        for w in words {
            yield ByEvent(kind=ByEventKind.TEXT, text=w.upper() + " ");
        }
        yield ByEvent(kind=ByEventKind.USAGE, usage=ByUsage(requests=1, output_tokens=len(words)));
        yield ByEvent(kind=ByEventKind.DONE, text=" ".join(words).upper());
    }
}

def shout(message: str) -> Iterator[ByEvent] by Echo();

sem shout = "Say the message again, louder.";

with entry {
    used = ByUsage();
    for event in shout("what a day") {
        if event.kind == ByEventKind.TEXT {
            print("text:", repr(event.text));
        } elif event.kind == ByEventKind.USAGE and event.usage is not None {
            used.add(event.usage);
        } elif event.kind == ByEventKind.DONE {
            print("done:", event.text);
        }
    }
    print(used.requests, used.output_tokens);
}
```

```output
text: 'WHAT '
text: 'A '
text: 'DAY '
done: WHAT A DAY
1 3
```

An event is a `ByEvent`. Its `kind`, a `ByEventKind`, says which of its
fields it carries:

| `kind` | Says | Fields |
|---|---|---|
| `TEXT` | The next piece of the answer | `text` |
| `TOOL_CALL` | The answerer calls a tool | `tool` (its name), `args` (its arguments, by name), `call_id` (a name for this call) |
| `TOOL_RESULT` | What that call gave | `tool`, `call_id`, `result` (a `str`) |
| `USAGE` | What one request took | `usage` (a `ByUsage`) |
| `DONE` | The call is answered | `text` (the whole answer) |

A `ByEvent` holds `any`s (a tool's arguments), so it is not sendable and
does not cross between spaces. A server's endpoint that passes an answer on
as it comes is a stream of a type of its own
([Serving a space](../apps/server.md#streams)), here of the answer's pieces:

```jac
import from stdjac { ByEvent, ByEventKind }

def answer(question: str) -> Iterator[ByEvent] by llm();

sem answer = "Answer the question.";

def:pub ask(question: str) -> Iterator[str] {
    for event in answer(question) {
        if event.kind == ByEventKind.TEXT {
            yield event.text;
        }
    }
}
```

## Writing an answerer: `By`

An answerer is a class that conforms to `By`, an
[interface](interfaces.md) with one method. A program imports the interfaces,
`ByCall`, `ByChoice`, `ByEvent`, `ByEventKind`, `ByUsage` and `ByError` from
`stdjac` (`import from stdjac { By, ByCall }`):

| Name | What it is |
|---|---|
| `By` | The interface of an answerer that gives a result: `def invoke(call: ByCall) -> any abst;` |
| `ByStreams` | The interface of one that answers as it goes: `def stream(call: ByCall) -> Iterator[ByEvent] abst;` |
| `ByChooser` | The interface of one that chooses a walker's way: `def choose(choice: ByChoice) -> list[int] abst;` ([visit](visit.md#visit--by)) |
| `ByCall` | One call: `name: str`, `doc: str`, `args: dict[str, any]`, `arg_docs: dict[str, str]`, `result_schema: dict[str, any]`, `decode: Callable[[any], any] \| None`, `tools: list[ByTool]` |
| `ByTool` | A tool: `name: str`, `doc: str`, `schema: dict[str, any]`, `call: Callable[[dict[str, any]], any]` |
| `ByEvent`, `ByEventKind` | One event of a streamed call, and what it says ([above](#a-by-function-that-streams)) |
| `ByUsage` | What an answerer used to answer (below) |
| `ByChoice` | The choice a chooser is asked to make: `name: str`, `asker: dict[str, any]`, `at: dict[str, any]`, `options: list[dict[str, any]]` ([visit](visit.md#visit--by)) |
| `ByError` | The exception an answerer raises when it cannot produce the result |
| `schema[T]()` | The JSON schema of type `T`, as `result_schema` is made |

`invoke` returns the result through `call.decode`, which decodes a JSON value
as the declared type and raises `CodecError` (from `stdjac`) when it
does not fit. An answerer that takes `tools` declares a `tools` field for them.
One class may conform to several of the interfaces, as `llm`'s does.

`ByUsage` counts what an answerer used, a model's requests for one:

| Field | Counts |
|---|---|
| `requests: int` | The requests made |
| `input_tokens: int`, `output_tokens: int` | The tokens they read and wrote |
| `cache_read_tokens: int`, `cache_write_tokens: int` | The input tokens read from the model's cache, and written to it |
| `seconds: float` | The time the requests took |
| `model: str` | The model that answered |

Every field starts at 0 (`model` at `""`). `total.add(more)` adds `more`'s
counts to `total`'s, and takes its `model` when it names one.

This answerer has no model, and prints what the call carries:

```jac
import from stdjac { By, ByCall }

enum Mood {
    HAPPY,
    SAD,
}

obj Verdict {
    has mood: Mood,
        score: int = 0;
}

sem Verdict.mood = "How the writer feels.";
sem Verdict.score = "0 to 10: how strongly.";

"""An answerer without a model, printing what a call carries."""
obj Canned(By) {
    has tools: list[any] = [];

    def invoke(call: ByCall) -> any {
        print("name:", call.name);
        print("doc:", call.doc);
        print("args:", call.args);
        print("arg docs:", call.arg_docs);
        print("schema:", call.result_schema);
        tool = call.tools[0];
        print("tool:", tool.name, "|", tool.doc, "|", tool.call({"word": "day"}));
        return call.decode({"mood": "HAPPY", "score": 7});
    }
}

def lookup(word: str) -> str {
    return word.upper();
}

sem lookup = "Look a word up.";

def judge(text: str, strict: bool = False) -> Verdict by Canned(tools=[lookup]);

sem judge = "Judge the mood of a text.";
sem judge.text = "The text to judge.";

with entry {
    v = judge("what a day");
    print(v, v.mood.name);
}
```

```output
name: judge
doc: Judge the mood of a text.
args: {'text': 'what a day', 'strict': False}
arg docs: {'text': 'The text to judge.'}
schema: {'type': 'object', 'properties': {'mood': {'enum': ['HAPPY', 'SAD'], 'description': 'How the writer feels.'}, 'score': {'type': 'integer', 'description': '0 to 10: how strongly.'}}, 'required': ['mood']}
tool: lookup | Look a word up. | DAY
Verdict(mood=<Mood.HAPPY: 1>, score=7) HAPPY
```

A reply that does not fit the result type is refused when it is decoded:

```jac
import from stdjac { By, ByCall, CodecError }

obj Wrong(By) {
    def invoke(call: ByCall) -> any {
        return call.decode({"n": "seven"});
    }
}

obj Count {
    has n: int;
}

def count(text: str) -> Count by Wrong();

with entry {
    try {
        print(count("a b c"));
    } except CodecError as e {
        print("CodecError:", e);
    }
}
```

```output
CodecError: .n: expected an int, got 'seven'
```

## Asking a model: `llm`

`llm(...)` asks a language model. `llm` is built in: a program says it
without importing it. It sends the function's
`sem` and its parameters' as the instructions and the arguments as JSON, asks
for a reply in the result's schema, runs the tools the model calls and gives
it their results, and decodes the final reply as the result type. It conforms
to `By`, to `ByStreams` and to `ByChooser`, so it gives a typed result,
streams an answer, and chooses a walker's way. What a program names beside
it is imported from `stdjac`: `Effort`, `Message`, `IterationAction`,
`IterationContext`, `on_usage`, and `LLM`, the class of what `llm(...)` gives.

Which model answers is not said in source. `llm` is an abstraction, and what
speaks to a model is the project's `llm` [plugin](../apps/plugins.md), named
in `jac.toml`: a function written `by llm()` is the same function under each.

```jac
import from stdjac { ByError }

obj Ticket {
    has title: str,
        urgent: bool = False,
        tags: list[str] = [];
}

sem Ticket.title = "A short title for the support ticket.";
sem Ticket.tags = "Lowercase words naming the product areas involved.";

def triage(message: str) -> Ticket by llm(max_tokens=500, max_output_retries=2);

sem triage = "Turn a customer's message into a support ticket.";
sem triage.message = "The message as the customer wrote it.";

with entry {
    try {
        print(triage("The app crashes when I upload a photo."));
    } except ByError as e {
        print("could not triage:", e);
    }
}
```

`llm` takes these keyword arguments:

| Argument | Default | Meaning |
|---|---|---|
| `max_tokens` | 4000 | The most tokens one reply may have |
| `effort` | `Effort.DEFAULT` | How hard the model works at it, where its provider has such a setting: `Effort.LOW`, `Effort.MEDIUM`, `Effort.HIGH`, or the provider's own choice |
| `tools` | `[]` | Functions the model may call, each described by its `sem` and its parameters' |
| `max_react_iterations` | 8 | Rounds of tool calls before the model must answer |
| `on_iteration` | `None` | A `Callable[[IterationContext], IterationAction]` called after each round of tool calls; returning `IterationAction.ABORT_WITH_SUMMARY` makes the model answer now |
| `max_output_retries` | 1 | How many times a reply that does not fit the result type is sent back to be corrected |
| `system_prompt` | `""` | Instructions said to the model before the function's `sem` |
| `conversation` | `None` | A `list[Message]`: the turns before this call ([below](#conversations)) |
| `parallelize` | `False` | `True` runs the tool calls of one round at once, each on a thread of its own, with the context variables of the thread that made the call |
| `select` | 1 | For `visit ... by`: how many of the nodes to choose, a number or a `(least, most)` pair |
| `intent` | `""` | For `visit ... by`: what the choice is for, said to the model |

A call raises `ByError` when the model's provider cannot be reached or
answers with an error, when every model declines the request, and when the
reply still does not fit the result type after the retries. A streamed call
raises it where its events are read.

### The anthropic plugin

`anthropic`, the standard `llm` plugin, asks a model through Anthropic's
Messages API over HTTP. Its settings, in `[llm.anthropic]`:

| Setting | Type | Default | Meaning |
|---|---|---|---|
| `model` | `str` | `claude-sonnet-5-5` | The model that answers. `JAC_LLM_MODEL` where the program runs |
| `address` | `str` | `https://api.anthropic.com` | Where the API is, or a gateway to it: requests go to `<address>/v1/messages`. `JAC_LLM_ADDRESS` |
| `timeout` | `int` | 60 | Seconds one request may take |
| `retries` | `int` | 0 | How many times a request the API refuses for load (408, 409, 429, 5xx) or cannot be reached with is made again, after 2, 4, 8 ... seconds |
| `key` | `Secret` | `ANTHROPIC_API_KEY` | The API key, read from that variable of the environment where the program runs, and never written in `jac.toml`. Without it a call raises `ByError` |

```toml
[llm.anthropic]
model = "claude-sonnet-5-5"
timeout = 30
```

The instructions (the `system_prompt`, the `sem`s) are sent marked for the
API's prompt cache, so the requests of one call, and calls with the same
instructions, read them from it: `ByUsage` counts those tokens apart. A
request the model's safety classifiers decline re-runs on the API's default
fallback model.

### Writing a model plugin

A plugin for another provider conforms to `llm.contract`'s `Model`
([Plugins](../apps/plugins.md#what-a-plugin-imports)):
`def ask(request: ModelRequest) -> Iterator[ByEvent] abst;`, after
`def open(host: dyn Host) abst;`, the first thing asked of it. `ask` makes one
request and gives its events: each piece of the answer's text as a `TEXT`
event, for a `live` request, and last a `DONE` whose `value` is the
`ModelReply`. The rounds of tool calls, the retries of a reply that does not
fit and conversations are stdjac's, the same for every plugin.

| Type | Holds |
|---|---|
| `ModelRequest` | `system`, the instructions; `messages: list[Message]`; `tools: list[ModelTool]` (each a `name`, a `doc` and a JSON `schema`); `result_schema`, which the answer must fit (`None` for text); `max_tokens`; `effort`; `answer_now`, when the model may call no more tools; `live`, when the answer is wanted as it is written |
| `ModelReply` | `message`, the model's (`TEXT` parts, `TOOL_CALL` parts, and `KEPT` parts for what only the provider reads back); `stop`, a `Stop` (`END`, `TOOLS`, `MAX_TOKENS`, `REFUSED`); `usage`, a `ByUsage` |

The text of a reply asked to fit a schema is the JSON value itself.

### Streaming

`def chat(...) -> Iterator[ByEvent] by llm(...);` asks the API for its reply
as it is written. The events of one call, in order:

- for each request it makes: a `TEXT` for each piece of text as the model
  writes it, then a `USAGE`; when the model called tools, a `TOOL_CALL` for
  each, the tools run, and a `TOOL_RESULT` for each, and the next request
  follows;
- then one `DONE`, whose `text` is everything the model said in the call.

### Conversations

`conversation` is the turns before the call, a `list[Message]`
(`Message` is imported from `stdjac`). The model is sent them before the call's arguments, and when
the call has answered, its own messages are appended to the list: the
arguments, each round of tool calls and their results, and the answer. The
caller that keeps the list keeps the conversation.

| Name | Fields |
|---|---|
| `Message` | `role: str` (`"user"` or `"assistant"`), `parts: list[Part]` |
| `Part` | `kind: PartKind`, and by its kind: `text` for `TEXT`; `name`, `input` (the arguments, as the JSON text the model wrote) and `id` for `TOOL_CALL`; `id`, `text` (what the tool gave) and `failed` for `TOOL_RESULT` |
| `PartKind` | `TEXT`, `TOOL_CALL`, `TOOL_RESULT` |

A `Message` is an `obj` of sendable fields: a program may keep a
conversation in a node's field, and send it across a crossing.

<!-- example: not checked: it asks a model, which needs a key and the network -->
```jac
import from stdjac { ByEvent, ByEventKind, ByUsage, Message, on_usage }

def lookup(word: str) -> str {
    return word.upper();
}

sem lookup = "Look a word up.";

def chat(message: str, history: list[Message]) -> Iterator[ByEvent] by llm(
    conversation=history, tools=[lookup], system_prompt="Answer in one sentence."
);

sem chat = "Talk with the user.";

glob spent: ByUsage = ByUsage();

with entry {
    on_usage(lambda (used: ByUsage) { spent.add(used) });
    history: list[Message] = [];
    for turn in ["hello", "and again"] {
        for event in chat(turn, history) {
            if event.kind == ByEventKind.TEXT {
                print(event.text, end="");
            } elif event.kind == ByEventKind.TOOL_CALL {
                print(f"[{event.tool} {event.args}]");
            } elif event.kind == ByEventKind.DONE {
                print();
            }
        }
    }
    print(len(history), "messages kept,", spent.requests, "requests");
}
```

With a model that answers the first turn in one request and calls `lookup`
in the second, it prints the answers as they are written, and ends:

```text
Hi there
Looking. [lookup {'word': 'again'}]
It is AGAIN.
6 messages kept, 3 requests
```

`history` is passed whole to the answerer, so it is the answerer's and not an
argument the model is sent as JSON
([above](#a-parameter-the-answerer-takes-whole)): the model is sent `message`.

### What a call used

- **`on_usage(f)`** registers `f`, a `Callable[[ByUsage], None]`, for the
  whole program. It is called after each request any `llm()` makes, with
  what that request used, on the thread that made it. What a call costs is
  the program's to work out from the counts.
- **A streamed call** gives the same `ByUsage` in its `USAGE` events.
- **`on_iteration`** is given an `IterationContext`: `iteration`, the rounds
  of tool calls the call has made, and `usage`, what its requests have used
  so far.

## What `sem` strings are read by

A `sem` is a description for whatever reads declarations: it does not change
what the program computes. `sem Doc.title = "The document's title.";` gives
`title` no value: `Doc().title` is still its default.

- A `by` call reads the function's `sem` (as `ByCall.doc`), its parameters'
  (`arg_docs`), the `sem`s of the result type's fields (the schema's
  `description`s) and each tool's and its parameters': a function's, or a
  method's for a tool that is a method. An enum's schema says what each
  member with a `sem` means (`CRITICAL: Breaks production, ...; LOW: ...`),
  after the `sem` of the field or parameter that holds it.
- `visit ... by` reads the `sem`s of the classes it shows the chooser, the
  walker's, the nodes' and the edges', and of their fields
  ([visit](visit.md#visit--by)).
- [Compile-time reflection](reflection.md) reads them as the `doc` of
  `fields(T)`, `params(f)` and each of `members(T)`.

A `sem` is written in the module that declares its target, and names
something that module declares: one that names no class, function, method,
parameter, field or enum member is E2018, and one for a name imported from another module is E2198
(it would be read by nothing, since a target's `sem`s are looked for where
the target is declared). A docstring is not a `sem`: it documents the code
for its reader, and a `sem` describes the declaration to an answerer.

## What is rejected

| Code | When |
|---|---|
| E0033 | A `by` function with no return type |
| E1229, E0109 | A `by` function whose result type has no JSON schema |
| E5090 | `by` on a method, an `impl` with a `by` body, the `by` operator in an expression (`a by b`) anywhere but a `visit` statement, a tool that is a method of a parameter whose type is not one class |
| E1053 | An answerer that does not conform to the interface its use asks for: `By` for a result, `ByStreams` for `Iterator[ByEvent]`, `ByChooser` for `visit ... by` |
| W2001 | A `by` expression that names what the module does not import |
| E0156 | `sem x is "..."` |
| E2018 | A `sem` whose target is no class, function, method, parameter, field or enum member: a member the enum does not have, for one |
| E2198 | A `sem` for something another module declares |
| E0002 | A `sem` without its `;` |

```jac
# expect: E0033
def summarize(text: str) by llm();
```

```jac
# expect: E5090 x2
obj Agent {
    def answer(q: str) -> str by llm();
}

def plain(q: str) -> str;

impl plain(q: str) -> str by llm();
```

```jac
# expect: E1229 x2, E0109 x2
def pair(text: str) -> tuple[int, int] by llm();

def scorer(text: str) -> Callable[[int], int] by llm();
```

```jac
# expect: E2018 x2, E2198
import from os { getcwd }

obj Doc {
    has title: str = "";
}

sem Doc.heading = "Doc declares no field or method of this name.";
sem Article.title = "Nothing here is named Article.";
sem getcwd = "Declared in another module.";
```

```jac
# expect: E2018 x2, E5090
enum Mood {
    HAPPY,
    SAD,
}

obj Desk {
    def look(word: str) -> str {
        return word;
    }
}

sem Mood.CALM = "Mood has no member of this name.";
sem Desk.look.page = "look has no parameter of this name.";

def ask(d: Desk | None, word: str) -> str by llm(tools=[d.look]);
```

```jac
# expect: E1053
import from stdjac { By, ByCall, ByEvent }

obj Plain(By) {
    def invoke(call: ByCall) -> any {
        return call.decode("done");
    }
}

def chat(message: str) -> Iterator[ByEvent] by Plain();
```

```jac
# expect: E0156
obj Doc {
    has title: str = "";
}

sem Doc.title is "The document's title.";
```

```jac
# expect: W2001, E5090
def title(text: str) -> str by Plain();

with entry {
    y = 3 by 4;
}
```

## Differences from Python and from the reference design

- **Python has no counterpart in the language**; a library call does this
  there, and its result is whatever the library returns. Here the result is
  decoded and checked as the declared type.
- **Here `llm` is built in**, and any class conforming to
  `By` may answer a `by` function. Which model `llm()` asks is the project's
  `llm` plugin, in `jac.toml`, where the reference design's byllm names a model in source.
- **In the reference design a method may be declared `by llm()`; here only a function may**
  (E5090). A method is a tool of a `by` function through the parameter it is
  called on (`tools=[r.read_file]`).
- **In the reference design `visit [-->] by llm();` takes whatever byllm returns; here the
  chooser conforms to `ByChooser`**, the nodes are a list of one node type,
  and the walker visits those chosen, in the order chosen.
- **In the reference design `sem x is "..."` is accepted; here the one spelling is `sem x =
  "...";`** (E0156).

## See also

- [visit](visit.md#visit--by): `visit <nodes> by <chooser>;`.
- [Reflection](reflection.md): `fields`, `params` and their `doc`.
- [Interfaces](interfaces.md): `By` is an interface.
- [Impl blocks](impl.md): the dotted paths a `sem` shares with `impl`.
