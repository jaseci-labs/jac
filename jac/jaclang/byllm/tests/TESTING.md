# Testing byLLM

How the byLLM suite fakes a model, which helper to reach for, and the rules a new test
follows. The helpers live in [`support.jac`](support.jac).

## Running it

```bash
# Once per binary: the dependencies CI installs for this suite.
jac install "litellm>=1.102.1,<1.103.0" "pillow>=12.0.0,<13.0.0" \
  "httpx>=0.27.0" "loguru>=0.7.2,<0.8.0" --global

# The suite, as CI's byllm lane runs it.
JAC_TEST_STRICT=1 jac test jac/jaclang/byllm/tests \
  --ignore jac/jaclang/byllm/tests/test_mtir_integration.jac

# One file, or one test in it.
JAC_TEST_STRICT=1 jac test jac/jaclang/byllm/tests/test_usage.jac -t "usage_step fires for the recovery call"

# The MTIR file, from a fresh copy outside the checkout, as the sealed lane runs it.
rm -rf /tmp/byllm-tests && cp -r jac/jaclang/byllm/tests /tmp/byllm-tests
JAC_TEST_STRICT=1 jac test /tmp/byllm-tests/test_mtir_integration.jac
```

`JAC_TEST_STRICT=1` turns a skip into a failure, so a lane that should run everything
cannot pass by skipping. CI sets it on the byllm lane and the sealed MTIR step.

| Guard | Without strict | With strict |
|---|---|---|
| a missing dependency at import, `require_module("PIL")` | skips | fails |
| `need_outside_jaclang(path)` | skips | fails |
| `need("cv2", "OpenCV")`, for a dependency CI does not install | skips | skips |

`test_mtir_integration.jac` runs in place too, without strict, and three of its tests
skip there. A file inside the jaclang package compiles into the compiler's own program,
so the MTIR a fixture registers never reaches `JacRuntime.program`, which is what those
tests read. `need_outside_jaclang()` asks the compiler where a fixture goes.

## What is fake and what is real

`MockLLM` replaces only the network call. Everything above it runs as it does in
production: the request byLLM builds, the reply it parses, retries, compaction, usage and
cost.

```mermaid
flowchart LR
    A["by llm() call site"] --> B["BaseLLM.invoke<br/>ReAct loop, retries, compaction"]
    B --> C["dispatch_*<br/>build request, parse reply,<br/>record usage and cost"]
    C --> D["model_call_*<br/>the network"]
    D -. "MockLLM answers here" .-> C
```

Because the model name is only a label, `MockLLM(model_name="gpt-4o-mini")` prices its
calls exactly as the real model would.

## Scripting a model

Queue the replies, then read back what was sent.

```jac
llm = MockLLM(outputs=[call("lookup", {"q": "x"}), say("done")]);
def task(q: str) -> str by llm(tools=[lookup]);
assert task("x") == "done";
assert "lookup" in tool_names(llm.seen[0]);
```

| Queue entry | The model... |
|---|---|
| a value (`42`, `Person(...)`, `Level.HIGH`) | answers with that typed value |
| `say(text, usage=, finish_reason=, model=)` | answers with text; `finish_reason="length"` truncates it |
| `call(name, args, call_id=, usage=)` | calls one tool; `args` is a dict or a JSON string |
| `calls([(name, args, id), ...])` | calls several tools in one turn |
| `finish(output, usage=)` | calls `finish_tool` with `output` |
| `fail(error, content=, after=)` | raises `error`; a stream first sends the first `after` chunks of `content` (`after=0` sends none) |
| `fail(error, reply=entry)` | raises `error`; a stream first sends the whole `entry`, any row of this table but `fail` |
| `(entry, {"prompt_tokens": ...})` | answers with `entry` and reports that usage |

What a provider reports about a reply, and a real model class:

| Need | Use |
|---|---|
| the provider reports a different model than was asked for, as after a fallback | `say(..., model="...")`, `call(..., model="...")` |
| a stream that drops after sending a reply | `fail(error, reply=call(...))` |
| tool-call fragments with no id or name | `call(..., unnamed_fragments=True)` |
| a stream carrying litellm's `logging_obj` | `MockLLM(logging_obj=...)` |
| a real `Model` or `LocalLLM`, with its own request shaping | `with scripted(model, replies) { ... }` |
| a routing prompt answered by reading its candidates | `RoutingLLM(pick=...)` |

## Reading what happened

| Question | Helper |
|---|---|
| what went out on call `n` | `llm.sent(key)[n]`, `sent_messages(llm, n)` |
| message roles, in order | `roles(llm, n)` |
| the user turn's content blocks and media | `user_blocks(llm, n)`, `media_blocks(llm, n)`, `data_url(block)` |
| did some text reach the model at all | `prompt_text(llm, n)` |
| which tools were offered | `tool_names(params)` |
| the routing candidates offered | `routing_candidates(params)` |
| the events of a `logging=True` stream | `stream_events(stream)`, `events_of(events, kind)`, `event_types(events)` |
| the answer text of a stream | `chunk_text(events)` |
| what byLLM logged through loguru: `llm.jac` and its impls, `visit_routing.jac` | `with capture_loguru() as logs`, then `logs.text()` |
| what it logged through `logging`: `types`, `mcp`, `parallel`, `telemetry`, `model_cache` | `with capture_logs(name=) as logs`, then `logs.text()` |
| every queued reply was used | `llm.exhausted()` |

Lower level:

| Need | Helper |
|---|---|
| an `MTRuntime` to hand a dispatch method directly | `mk_run(resp_type=, tools=, stream=, call_params=, messages=, finish=)` |
| one litellm text chunk | `text_chunk(text)` |
| skip when a dependency is missing; see the guard table above | `require_module(...)` from `jaclang.testing.requires`, or `need(...)` |

## Fixtures

Everything under `fixtures/` is input, never a test. A `.jac` fixture declares the
`by llm()` functions and types a test needs, together with the model they are bound to,
so it compiles and runs on its own. It has no `with entry`, no `print` and no `assert`.

| Kind | Examples | A test uses it by |
|---|---|---|
| program | `basic.jac`, `scope_dir/module_alpha.jac`, `enum_no_value.jac` | `load_fixture(name)`, or `JacProgram().compile(fixture_path(file))` |
| graph | `routing_graph.jac`, `agent_graph.jac` | a static `import from fixtures.routing_graph { ... }` |
| config | `compaction_config/`, `jac_toml_gemini/` | `get_byllm_config(Path(fixture_path(dir)))` |
| project, a module beside its own `jac.toml` | `system_prompt_override/` | `Jac.jac_import(name, base_path=fixture_path(dir))` |
| media | `image.jpg`, `SampleVideo_1280x720_2mb.mp4` | `Image(fixture_path(file))` |

## Rules

**Fake the network, not byLLM.** Never patch `model_call_*`, `dispatch_*` or other
byLLM internals to fake a reply; queue it on `MockLLM` or `scripted()`.
Patch litellm itself (`litellm.completion`, a Router) only when that boundary is what the
test is about.

**Assert on what reached the model or what came back.** Read `llm.sent(...)`, the return
value, the events or the captured log. Never scrape stdout; the one exception is a test
whose subject is that byLLM prints nothing.

**Pair a negative assert with a positive one.** `secret not in logs.text()` also passes when
the capture saw nothing, such as `capture_logs()` around a loguru message. First assert
that the same capture holds something the call does log.

**A test that calls a fixture function binds its own model.** A fixture's model gives
fixed answers, and `load_fixture()` returns a cached module, so every test that loads it
would share them. Assign `module.llm` before calling.

**A fixture with no model of its own declares `glob llm: any = None;`.** A test assigns
its model after import. Without `: any` the global infers `NoneType` and the assignment fails
`jac check`.

**Graph fixtures are imported statically.** A module from `load_fixture()` is untyped, so
`root ++> g.Desk()` fails strict checking. Spawn on a node the test creates; never spawn
from `root` or assert on `[root -->]`, which accumulates across tests.

**One test per behavior; variations are rows.** Loop over a table of cases and put the
case label in every assert message.

**Helpers are defined once, here.** A helper two files need goes into `support.jac`.
