---
name: language-models-and-agents
description: Use when a program calls a language model (an LLM) - a function a model answers with a typed value, an AI agent whose tools are the program's own functions, a chat that streams its answer to a page or a terminal and keeps its history - with by llm(), tools, sem and Iterator[ByEvent], the model and ANTHROPIC_API_KEY, in place of calling a model's HTTP API by hand.
---
# Language models and agents

## When to use this

Use it when a program asks a language model anything: to read text into a typed value, to answer
a user, or to act as an agent that calls the program's functions and drives its pages.

A model call is part of the language: a function declared `by llm()` in place of a body is
answered by the model, which is sent the function's `sem` strings, its arguments and its tools,
and whose answer comes back as the declared type or as a stream of events. The built-in `llm` makes the
requests, reads the streamed reply and runs the tool loop: write none of that over `urllib`, and
install no model's SDK from PyPI or npm for it.

Load `writing-jac` first. The server a chat runs on: `building-an-app`; its pane:
`pages-and-components`.

## Before you start

```sh
jac docs by-and-sem      # by, sem, tools, streaming, conversations, every argument of llm()
jac docs crossings       # how a page reads a stream: "Calling a stream"
```

`jac check` and `jac build` need no API key; a call does (step 4).

## Steps

1. **A function the model answers.** `def read_expense(receipt: str) -> Expense by llm();`
   gives an `Expense`, decoded and checked, or raises `ByError` (from `stdjac`). The model is
   sent the arguments and the result's schema, and its instructions are the `sem`s: the
   function's (`sem read_expense = "...";`), its parameters' (`sem read_expense.receipt = "...";`)
   and the result's fields' (`sem Expense.currency = "Its ISO code, such as EUR.";`). A docstring
   is for the code's reader; the model never sees it. The result's type needs a JSON schema,
   which an `obj` of fields that have one, an enum (each member's `sem` says what that choice
   means), a `list`, a `str`, a number and a `bool` have.

2. **An agent: give it tools.** A tool is an ordinary typed function with a `sem`, listed in the
   `by` call: `by llm(tools=[add_task, list_tasks])`. The model calls tools in rounds, and the
   library runs each and sends the model what it returned (as JSON, a `str` as it is) until the
   model answers, which after `max_react_iterations` rounds (8) it must. A tool that raises does
   not end the call: the model is told it failed, and why. A method of a parameter is a tool too
   (`tools=[r.read_file]`). Avoid, for now, a list held in a variable (`tools=TOOLS`): a known
   defect compiles it and gives the model no tools.

3. **Stream the answer and keep the conversation.** Declared `-> Iterator[ByEvent]`, the
   function returns at once and its events come as the model writes: `TEXT` pieces, a
   `TOOL_CALL` and a `TOOL_RESULT` for each tool it runs, a `USAGE` after each request, then
   `DONE`. `conversation=history`, a `list[Message]` parameter passed whole, is the turns before
   this one; the call appends its own when it has answered, so the caller that keeps the list
   keeps the chat. The whole agent, in a terminal (`agent.jac`):

```jac
import sys;
import from stdjac { ByError, ByEvent, ByEventKind, Message }

node Task {
    has title: str,
        done: bool = False;
}

def add_task(title: str) -> str {
    root ++> Task(title=title);
    return "added";
}

sem add_task = "Add a task to the user's list.";
sem add_task.title = "The task, in a few words.";

def list_tasks -> list[str] {
    return [t.title + (" (done)" if t.done else "") for t in [root --> [?:Task]]];
}

sem list_tasks = "The user's tasks, oldest first.";

def assistant(message: str, history: list[Message]) -> Iterator[ByEvent] by llm(
    tools=[add_task, list_tasks], conversation=history
);

sem assistant = "Keep the user's task list with the tools. Answer in a sentence or two.";
sem assistant.message = "What the user said.";

with entry {
    history: list[Message] = [];
    for line in sys.stdin {
        try {
            for event in assistant(line.strip(), history) {
                if event.kind == ByEventKind.TEXT {
                    print(event.text, end="");
                } elif event.kind == ByEventKind.TOOL_CALL {
                    print(f"[{event.tool} {event.args}]");
                }
            }
            print();
        } except ByError as e {
            print("no answer:", e);
        }
    }
}
```

4. **Give it the key, choose the model, and run it.**
   - The key is `ANTHROPIC_API_KEY`, read from the environment of the program that makes the
     call, at each request: the shell's for `jac run`, the server's for an app (a page's call
     runs there). It is never written in `jac.toml` and never built into an artifact. A key kept
     under another name is passed as `ANTHROPIC_API_KEY="$OTHER_NAME"`. Without it a call raises
     `ByError` (`ANTHROPIC_API_KEY isn't set`), a streamed call where its first event is read.
   - The model is `JAC_LLM_MODEL` where the program runs, else `model` under `[llm.anthropic]` in
     the project's `jac.toml`, else the plugin's default. `address` there, or `JAC_LLM_ADDRESS`,
     sends the requests to a gateway in place of Anthropic's API.

```sh
jac check agent.jac                                  # prints nothing
ANTHROPIC_API_KEY="$OTHER_NAME" jac run agent.jac    # then type a line
```

5. **Serve it to a page.** Move the imports, the tools and `assistant` into the server space's
   module (`chat.jac`) unchanged, without the entry block: there `root` is the caller's, so each
   user has their own tasks. A `ByEvent` does not cross between spaces, so the endpoint streams
   pieces of a type of its own, declared in a module no space holds and wired to both sides
   (`building-an-app` step 5): `obj Piece { has kind: str; has text: str = ""; }`. The
   conversation is kept in a node, which the server keeps:

<!-- example: not checked: Piece comes from model.jac through the archwire's wire -->
```jac
node Chat {
    has history: list[Message] = [];
}

def:protect say(message: str) -> Iterator[Piece] {
    chat = Chat();
    found = [root --> [?:Chat]];
    if len(found) > 0 {
        chat = found[0];
    } else {
        root ++> chat;
    }
    try {
        for event in assistant(message, chat.history) {
            if event.kind == ByEventKind.TEXT {
                yield Piece(kind="text", text=event.text);
            } elif event.kind == ByEventKind.TOOL_CALL {
                yield Piece(kind="tool", text=event.tool);
            }
        }
    } except ByError as e {
        yield Piece(kind="error", text=str(e));
    }
}
```

A page reads it with `async for piece in say(text)` in an `async def`, adding each `text` piece
to the answer it shows. A `tool` piece is where the agent drives the page: on `add_task` it reads
the list again; for a tool whose work is the page's (`show(view: str)`), give `Piece` a field for
the tool's arguments.

## What a correct result looks like

- `jac check agent.jac` prints nothing, with or without a key.
- With the key, the line `add milk and eggs` prints `[add_task {'title': ...}]` for each task as
  the tool runs, and the answer as it is written. The next line, `what is left?`, calls
  `list_tasks`; an answer that refers to the line before shows the conversation is kept. Without
  the key each line prints `no answer: ANTHROPIC_API_KEY isn't set`.
- Served, `curl -N` of `say` with a signed-in caller's token (`building-an-app` step 4) prints
  `data: {"kind": "tool", "text": "add_task"}`, the text pieces as they come, and `event: end`.

## Mistakes to expect

| Code or symptom | Means | Fix |
|---|---|---|
| E0033 | A `by` function with no result type | Declare `-> T`, or `-> Iterator[ByEvent]` |
| E1229, E0109 | A result type with no JSON schema: `any`, a `tuple`, a function type | An `obj` of fields that have one |
| E5090 | `by` on a method | A function; the method becomes a tool, `tools=[r.method]` |
| E2233 on `llm` | `llm` is imported | Drop the import: `llm` is built in |
| E1308 on an endpoint | It streams `ByEvent`s, which do not cross | Stream a type of your own (step 5) |
| `ByError`: `ANTHROPIC_API_KEY isn't set` | No key where the call runs | Step 4 |
| The model never calls a tool | It is not in the list written in the `by` call, or its `sem` does not say when to use it | List it there, and say when in its `sem` |
| `ByError`: `<name>: the model's reply doesn't fit its result` | The reply did not decode as the type, after the retries | Say more in the fields' `sem`s; `max_output_retries=2` |

## Where to look things up

- `jac docs by-and-sem`: the rest of `llm()`'s arguments (`system_prompt`, `max_tokens`,
  `on_iteration` to stop a long turn, `parallelize` to run a round's tools at once), the
  `[llm.anthropic]` settings, `on_usage` and `ByUsage` for what calls use, `Message` and `Part`,
  an answerer of one's own (`By`, `ByStreams`), a plugin for another provider (`Model`), and
  `visit ... by llm()`.
- `jac docs apps/server`: streams, calls answered at once, `commit()` in a long stream.
- `jac docs apps/building`: deployment values, and the variables never built in.
- `jac docs E1229` (any code): its message and fix.
