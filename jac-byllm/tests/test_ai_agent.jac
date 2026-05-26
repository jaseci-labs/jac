"""Integration tests for the `jac ai` coding agent with a stubbed model.

The LLM is replaced by byLLM's `MockLLM`, scripted with a fixed sequence of
`MockToolCall` outputs, so each test drives the *real* agent ReAct loop
(`run_turn` over the `ask` by-function) through a deterministic scenario of
tool calls -- no network or real model involved -- and asserts the resulting
behaviours added on this branch:

- tool dispatch and the live-view rendering (`run_turn`),
- compiler-backed semantic queries (`find_symbol`),
- inline compiler feedback after a write, and its `inline_feedback` opt-out,
- incremental code-intelligence refresh and its `on_event` live-view stream,
- reverse-dependency fanout (an edit recompiling a module's importer),
- the full agent tool surface (every tool in `ask`'s tool list) exercised in
  one scripted session, asserting each tool's result.

Each test arms the agent module's session globals, runs one turn against a
throwaway project, and checks filesystem state, captured stdout, and the
code-intelligence event stream.
"""

import io;
import os;
import sys;
import shutil;
import tempfile;
import from pathlib { Path }
import jaclang.cli.ai_agent as agent;
import from jaclang.compiler.code_intel { CodeIntelligence }
import from byllm.lib { Model, MockToolCall }

glob _MODEL_SRC = "node User { has name: str; }\n",
     # A small ready-made project (nodes, an edge, a walker, an import + uses) so
     # every semantic tool has real structure to report against.
     FIXTURE_PROJECT = os.path.join(
         os.path.dirname(__file__), "fixtures", "ai_agent_project"
     );


"""Create a throwaway project (jac.toml + a model.jac node); return its path."""
def make_project -> str {
    proj = tempfile.mkdtemp(prefix="ai_agent_");
    (Path(proj) / "jac.toml").write_text("[run]\n");
    (Path(proj) / "model.jac").write_text(_MODEL_SRC);
    return proj;
}


"""Point the agent's session state at `ci` and a mock model scripted with
`outputs` (a list of MockToolCall steps ending in the final answer string).
Every code-intelligence event is captured into `events` and still rendered."""
def arm_agent(
    ci: CodeIntelligence,
    outputs: list,
    events: list,
    feedback: bool = True,
    verbose: bool = False
) {
    def on_evt(info: any) {
        events.append(info);
        agent._ci_event(info);
    }
    agent.agent_ci = ci;
    # Assign the observer through the `any`-typed module glob (as the agent
    # itself does) rather than the concretely-typed `ci`.
    agent.agent_ci.on_event = on_evt;
    agent.agent_ci_dirty = False;
    agent.agent_model = Model(model_name="mockllm", config={"outputs": outputs});
    agent.yolo_mode = True;
    agent.verbose = verbose;
    agent.show_stats = False;
    agent.inline_feedback = feedback;
    agent.reset_history();
}


"""Run one agent turn with stdout captured; return what it printed."""
def run_capture(message: str) -> str {
    cap = io.StringIO();
    old = sys.stdout;
    sys.stdout = cap;
    try {
        agent.run_turn(message);
    } finally {
        sys.stdout = old;
    }
    return cap.getvalue();
}


test "agent drives a scripted tool-call scenario end to end" {
    proj = make_project();
    ci = CodeIntelligence(proj_dir=proj);
    note = str(Path(proj) / "note.jac");
    events: list = [];
    arm_agent(
        ci,
        [
            MockToolCall(tool=agent.find_symbol, args={"name": "User"}),
            MockToolCall(
                tool=agent.write_file,
                args={"path": note, "content": "node Note { has title: str; }\n"}
            ),
            MockToolCall(tool=agent.find_symbol, args={"name": "Note"}),
            MockToolCall(
                tool=agent.edit_file,
                args={
                    "path": note,
                    "old_text": "has title: str;",
                    "new_text": "has title: str;\n    has done: bool = False;"
                }
            ),
            "Created the Note node and added a done field."
        ],
        events
    );
    out = run_capture("create a Note node, then add a done field");

    # The write and edit reached disk through the real tools.
    assert Path(note).exists();
    body = Path(note).read_text();
    assert "node Note" in body , body;
    assert "has done: bool" in body , body;

    # Each tool call was dispatched and rendered in the live view.
    assert "find_symbol" in out , out;
    assert "write_file" in out , out;
    assert "edit_file" in out , out;

    # The semantic query resolved the just-written node from the compiler --
    # proving the agent navigates by symbol table, and that a write is visible
    # to the next query (find_symbol("Note") sees the file just created).
    assert "node Note" in out , out;

    # Code intelligence loaded once, then refreshed incrementally per change,
    # and every refresh surfaced a live-view event.
    ops = [str(e["op"]) for e in events];
    assert "load" in ops , ops;
    assert "create" in ops , ops;
    assert "edit" in ops , ops;
    assert "code intel" in out , out;

    shutil.rmtree(proj, ignore_errors=True);
}


test "a write that breaks compilation surfaces inline compiler feedback" {
    proj = make_project();
    ci = CodeIntelligence(proj_dir=proj);
    bad = str(Path(proj) / "broken.jac");
    events: list = [];
    arm_agent(
        ci,
        [
            MockToolCall(tool=agent.find_symbol, args={"name": "User"}),
            MockToolCall(
                tool=agent.write_file,
                args={
                    "path": bad,
                    "content": "def f() -> int { return \"not an int\"; }\n"
                }
            ),
            "Wrote the file."
        ],
        events,
        verbose=True
    );
    out = run_capture("add a function");

    assert "write_file" in out , out;
    # write_feedback recompiled and reported the type error inline with the result.
    assert "compiler feedback" in out , out;

    shutil.rmtree(proj, ignore_errors=True);
}


test "the inline_feedback opt-out suppresses compiler feedback after a write" {
    proj = make_project();
    ci = CodeIntelligence(proj_dir=proj);
    bad = str(Path(proj) / "broken2.jac");
    events: list = [];
    arm_agent(
        ci,
        [
            MockToolCall(tool=agent.find_symbol, args={"name": "User"}),
            MockToolCall(
                tool=agent.write_file,
                args={"path": bad, "content": "def g() -> int { return \"nope\"; }\n"}
            ),
            "Done."
        ],
        events,
        feedback=False,
        verbose=True
    );
    out = run_capture("add g");

    assert "write_file" in out , out;
    assert "compiler feedback" not in out , out;
    # With feedback off the project model is left dirty for the next query.
    assert agent.agent_ci_dirty , "expected agent_ci_dirty after a feedback-off write";

    shutil.rmtree(proj, ignore_errors=True);
}


test "editing a depended-on module recompiles its importer" {
    proj = make_project();
    ci = CodeIntelligence(proj_dir=proj);
    feat = str(Path(proj) / "feat.jac");
    modl = str(Path(proj) / "model.jac");
    events: list = [];
    arm_agent(
        ci,
        [
            MockToolCall(tool=agent.find_symbol, args={"name": "User"}),
            MockToolCall(
                tool=agent.write_file,
                args={
                    "path": feat,
                    "content": "import from model { User }\ndef mk() -> User { return User(name=\"x\"); }\n"
                }
            ),
            MockToolCall(
                tool=agent.edit_file,
                args={
                    "path": modl,
                    "old_text": "has name: str;",
                    "new_text": "has name: str;\n    has age: int = 0;"
                }
            ),
            "Extended the model."
        ],
        events
    );
    run_capture("add a feature module, then extend the model");

    # The edit to model.jac must fan out to feat.jac, which imports it -- proving
    # the centralized reverse-dependency map (record_module_dependencies) is
    # complete. model + its importer = 2 modules recompiled on the edit.
    edit_events = [
        e
        for e in events
        if str(e["op"]) == "edit"
    ];
    assert len(edit_events) >= 1 , [str(e["op"]) for e in events];
    assert int(edit_events[-1]["recompiled"]) >= 2 , edit_events[-1];

    shutil.rmtree(proj, ignore_errors=True);
}


"""Copy the fixture project into a fresh temp dir; return its path."""
def fixture_copy -> str {
    proj = tempfile.mkdtemp(prefix="ai_agent_tour_");
    shutil.copytree(FIXTURE_PROJECT, proj, dirs_exist_ok=True);
    return proj;
}


"""Drive one agent turn, returning a {tool_name: full_result} map.

Iterates the `ask` event stream directly (rather than `run_turn`) so each tool
call is paired with its *untruncated* result -- the level at which tool
behaviour, not its rendering, is asserted. Each scripted output is a single
tool call, so tool_call/tool_result events alternate and the most recent
tool name names the result that follows."""
def collect_tool_results(message: str) -> dict[str, str] {
    results: dict[str, str] = {};
    # `ask` is typed `-> str` for byLLM's contract but yields StreamEvents when
    # streaming; iterate via an `any` handle so attribute access type-checks.
    stream: any = agent.ask(message);
    cap = io.StringIO();
    old = sys.stdout;
    sys.stdout = cap;
    try {
        for event in stream {
            # tool_result events name their own tool; byLLM caps the result
            # string at `max_tool_result_length` (default 500), so assertions
            # target content near the head of each result.
            if event.event_type == "tool_result" {
                results[str(event.data.get("tool", ""))] = str(
                    event.data.get("result", "")
                );
            }
        }
    } finally {
        sys.stdout = old;
    }
    return results;
}


test "the full agent tool surface behaves across one scripted session" {
    proj = fixture_copy();
    model = str(Path(proj) / "model.jac");
    feat = str(Path(proj) / "feature.jac");
    app = str(Path(proj) / "app.jac");
    (Path(app)).write_text("with entry { print(\"BOOTED_OK\"); }\n");
    # Shorten start_app's boot window (default 12s) so the tour stays quick.
    # Not so short that a cold-cache runner captures nothing before the stop.
    os.environ["JAC_AI_START_TIMEOUT"] = "5";

    ci = CodeIntelligence(proj_dir=proj);
    events: list = [];
    # One MockToolCall per agent tool, in a plausible explore -> edit -> verify
    # order, then the final answer. Every tool in `ask`'s tool list is covered.
    arm_agent(
        ci,
        [
            MockToolCall(tool=agent.project_map, args={}),
            MockToolCall(tool=agent.list_dir, args={"path": proj}),
            MockToolCall(tool=agent.read_file, args={"path": model}),
            MockToolCall(tool=agent.grep, args={"pattern": "Crawler", "path": proj}),
            MockToolCall(tool=agent.find_symbol, args={"name": "User"}),
            MockToolCall(tool=agent.find_uses, args={"name": "User"}),
            MockToolCall(tool=agent.find_walkers, args={"node_type": "User"}),
            MockToolCall(tool=agent.context_slice, args={"name": "Crawler"}),
            MockToolCall(tool=agent.search_guides, args={"keyword": "persistence"}),
            MockToolCall(tool=agent.read_guide, args={"name": "jac-core-cheatsheet"}),
            MockToolCall(
                tool=agent.write_file,
                args={
                    "path": feat,
                    "content": "import from model { User }\nwalker Lister { can go with User entry { print(here.name); } }\n"
                }
            ),
            MockToolCall(
                tool=agent.edit_file,
                args={
                    "path": feat,
                    "old_text": "print(here.name);",
                    "new_text": "print(here.name, here.age);"
                }
            ),
            MockToolCall(tool=agent.jac_check, args={"path": model}),
            MockToolCall(
                tool=agent.run_command, args={"command": "echo HELLO_FROM_TOOL"}
            ),
            MockToolCall(tool=agent.start_app, args={"entry_file": app}),
            "Toured every tool."
        ],
        events
    );

    r = collect_tool_results("take a full tour of the project");

    # Every tool was reached.
    expected = [
        "project_map",
        "list_dir",
        "read_file",
        "grep",
        "find_symbol",
        "find_uses",
        "find_walkers",
        "context_slice",
        "search_guides",
        "read_guide",
        "write_file",
        "edit_file",
        "jac_check",
        "run_command",
        "start_app"
    ];
    for name in expected {
        assert name in r , f"{name} never produced a tool result; got {list(r.keys())}";
    }

    # Structural overview from the compiler -- archetypes across both files.
    assert "User" in r["project_map"] and "Crawler" in r["project_map"] , r[
        "project_map"
    ];
    assert "Wrote" in r["project_map"] , r["project_map"];

    # Filesystem + text tools.
    assert "model.jac" in r["list_dir"] and "walkers.jac" in r["list_dir"] , r[
        "list_dir"
    ];
    assert "node User" in r["read_file"] , r["read_file"];
    assert "walker Crawler" in r["grep"] , r["grep"];

    # Compiler-backed semantic tools.
    assert "node User" in r["find_symbol"] and "used in" in r["find_symbol"] , r[
        "find_symbol"
    ];
    assert "use" in r["find_uses"] and "walkers.jac" in r["find_uses"] , r["find_uses"];
    assert "Crawler" in r["find_walkers"] and "User" in r["find_walkers"] , r[
        "find_walkers"
    ];
    assert "Crawler" in r["context_slice"] , r["context_slice"];

    # Bundled reference guides: search returns a ranked list of "name: desc"
    # entries; read_guide returns the guide body. (Result strings are capped at
    # 500 chars by byLLM, so assert on shape, not a deep entry.)
    assert "jac-" in r["search_guides"] and ":" in r["search_guides"] , r[
        "search_guides"
    ];
    assert "no guides match" not in r["search_guides"] , r["search_guides"];
    assert len(r["read_guide"]) > 100 , r["read_guide"];

    # Mutating tools.
    assert "OK: wrote" in r["write_file"] , r["write_file"];
    assert "OK: edited" in r["edit_file"] , r["edit_file"];
    assert "here.age" in Path(feat).read_text() , "edit_file should have applied to disk";

    # Subprocess tools.
    assert "PASSED" in r["jac_check"] , r["jac_check"];
    assert "HELLO_FROM_TOOL" in r["run_command"] , r["run_command"];
    # start_app launches `jac start`, captures the boot logs, then stops it.
    # Assert the tool dispatched and returned real startup output -- not that the
    # app fully booted within the window (cold-cache compilation makes the exact
    # boot output, e.g. the entry's own print, racy across environments).
    sa = r["start_app"];
    assert "ERROR launching" not in sa and "DENIED" not in sa , sa;
    assert sa and "(no startup output)" not in sa , sa;

    os.environ.pop("JAC_AI_START_TIMEOUT", None);
    shutil.rmtree(proj, ignore_errors=True);
}
