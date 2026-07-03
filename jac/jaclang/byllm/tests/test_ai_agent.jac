"""Integration tests for the `jac ai` coding agent (OSP toolbox architecture).

The agent groups its tools into capability objects on a single `AgentRuntime`
composition root -- `agent.files`, `agent.proc`, `agent.semantic`, `agent.guides`,
`agent.web` -- drives phases with an `AgentSession` walker, and renders the live
view through `agent.view`. These tests exercise that surface:

- the file toolbox (writes/edits reach disk, with inline compiler feedback and
  the JavaScript-drift guard),
- the semantic toolbox answering from the compiler's symbol table,
- the guide and process toolboxes,
- the `note` memory tool writing to the session ledger,
- the renderer turning a byLLM event stream into the live view and turn tallies,
- one full Plan -> Build -> QA -> Done walker run driven by a scripted MockLLM.

The toolbox methods are called directly (no model needed), which keeps every
test but the last deterministic; the walker test scripts a single flat MockLLM
`outputs` list consumed across phases.
"""

import io;
import os;
import sys;
import shutil;
import tempfile;
import from pathlib { Path }
import jaclang.cli.ai_agent as ai;
import from jaclang.compiler.code_intel { CodeIntelligence }
import from jaclang.byllm.lib { Model, MockToolCall }

glob FIXTURE_PROJECT = os.path.join(
         os.path.dirname(__file__), "fixtures", "ai_agent_project"
     );


"""A fresh temp project (jac.toml + a User node); returns its path."""
def make_project -> str {
    proj = tempfile.mkdtemp(prefix="ai_agent_");
    (Path(proj) / "jac.toml").write_text("[run]\n");
    (Path(proj) / "model.jac").write_text("node User { has name: str; }\n");
    return proj;
}


"""Copy the structured fixture project into a fresh temp dir; return its path."""
def fixture_copy -> str {
    proj = tempfile.mkdtemp(prefix="ai_agent_tour_");
    shutil.copytree(FIXTURE_PROJECT, proj, dirs_exist_ok=True);
    return proj;
}


"""Point the shared runtime at `proj`: cwd, a real CodeIntelligence, yolo on.

Every code-intelligence event is appended to `events`. Returns the CI handle.
"""
def arm(proj: str, events: list, feedback: bool = True) -> CodeIntelligence {
    ci = CodeIntelligence(proj_dir=proj);
    def on_evt(info: any) {
        events.append(info);
    }
    ci.on_event = on_evt;
    ai.agent.ws.cwd = proj;
    ai.agent.ws.ci = ci;
    ai.agent.ws.ci_dirty = False;
    ai.agent.cfg.yolo_mode = True;
    ai.agent.cfg.show_stats = False;
    ai.agent.cfg.inline_feedback = feedback;
    ai.reset_session();
    return ci;
}


"""Run a thunk with stdout captured; return what it printed.

The agent's _term_output_enabled() guard suppresses console.print when
stdout is not a tty (so the terminal UI is not corrupted).  Patch isatty on the
StringIO cap so captured-output tests still see terminal prints.
"""
def capturing(run: any) -> str {
    cap = io.StringIO();
    setattr(cap, "isatty", lambda -> bool { return True; });
    old = sys.stdout;
    sys.stdout = cap;
    try {
        run();
    } finally {
        sys.stdout = old;
    }
    return cap.getvalue();
}


test "the file toolbox writes, reads, edits, lists, and greps" {
    proj = make_project();
    events: list = [];
    arm(proj, events);
    note = str(Path(proj) / "note.jac");

    wrote = ai.agent.files.write_file(note, "node Note { has title: str; }\n");
    assert "OK: wrote" in wrote , wrote;
    assert Path(note).exists();
    assert "node Note" in ai.agent.files.read_file(note);

    edited = ai.agent.files.edit_file(
        note, "has title: str;", "has title: str;\n    has done: bool = False;"
    );
    assert "OK: edited" in edited , edited;
    assert "has done" in Path(note).read_text();

    assert "note.jac" in ai.agent.files.list_dir("");
    assert "Note" in ai.agent.files.grep("Note", "");

    shutil.rmtree(proj, ignore_errors=True);
}


test "a write that breaks compilation surfaces inline compiler feedback" {
    proj = make_project();
    events: list = [];
    arm(proj, events);
    bad = str(Path(proj) / "broken.jac");

    out = ai.agent.files.write_file(bad, "def f() -> int { return \"not an int\"; }\n");
    # write_feedback recompiled and reported the type error inline with the result.
    assert "compiler feedback" in out , out;
    # The incremental recompile fired at least one live-view event.
    assert events , "the write should trigger a code-intelligence event";

    shutil.rmtree(proj, ignore_errors=True);
}


test "the inline_feedback opt-out suppresses feedback but still flags dirty" {
    proj = make_project();
    events: list = [];
    arm(proj, events, feedback=False);
    bad = str(Path(proj) / "broken2.jac");

    out = ai.agent.files.write_file(bad, "def g() -> int { return \"nope\"; }\n");
    assert "compiler feedback" not in out , out;
    # With feedback off the project model is left dirty for the next query.
    assert ai.agent.ws.ci_dirty , "expected ci_dirty after a feedback-off write";

    shutil.rmtree(proj, ignore_errors=True);
}


test "the file toolbox rejects JavaScript/React drift before it touches disk" {
    proj = make_project();
    events: list = [];
    arm(proj, events);

    # React/JS syntax in a .jac file is refused and never written.
    jac_path = str(Path(proj) / "Comp.jac");
    out = ai.agent.files.write_file(jac_path, "export function Comp() { return 1; }\n");
    assert "REFUSED" in out , out;
    assert not Path(jac_path).exists() , "drifted file must not reach disk";

    # A .ts file is refused outright.
    ts_out = ai.agent.files.write_file(str(Path(proj) / "x.ts"), "const x = 1;");
    assert "REFUSED" in ts_out , ts_out;

    shutil.rmtree(proj, ignore_errors=True);
}


test "the semantic toolbox answers from the compiler's symbol table" {
    proj = fixture_copy();
    events: list = [];
    arm(proj, events);

    fs = ai.agent.semantic.find_symbol("User");
    assert "node User" in fs and "used in" in fs , fs;
    pm = ai.agent.semantic.project_map();
    assert "User" in pm and "Crawler" in pm , pm;
    fw = ai.agent.semantic.find_walkers("User");
    assert "Crawler" in fw , fw;
    fu = ai.agent.semantic.find_uses("User");
    assert "use" in fu , fu;
    cs = ai.agent.semantic.context_slice("Crawler");
    assert "Crawler" in cs , cs;

    shutil.rmtree(proj, ignore_errors=True);
}


test "the guide toolbox searches and reads the bundled guides" {
    proj = make_project();
    events: list = [];
    arm(proj, events);

    sg = ai.agent.guides.search_guides("persistence");
    assert "jac-" in sg and ":" in sg , sg;
    assert "no guides match" not in sg , sg;
    assert len(ai.agent.guides.read_guide("jac-core-cheatsheet")) > 100;

    shutil.rmtree(proj, ignore_errors=True);
}


test "the process toolbox runs shell commands and jac_check" {
    proj = fixture_copy();
    events: list = [];
    arm(proj, events);

    assert "HELLO_FROM_TOOL" in ai.agent.proc.run_command("echo HELLO_FROM_TOOL");
    assert "PASSED" in ai.agent.proc.jac_check("model.jac");

    shutil.rmtree(proj, ignore_errors=True);
}


test "the note tool records onto the active session's ledger" {
    proj = make_project();
    events: list = [];
    arm(proj, events);
    ai.agent.active_session = ai.AgentSession(
        objective="x", ledger=ai.Ledger(), stats=ai.TurnStats()
    );

    out = ai.agent.note("the build directory is app/");
    assert "noted:" in out , out;
    assert "the build directory is app/" in ai.agent.active_session.ledger.notes;

    shutil.rmtree(proj, ignore_errors=True);
}


"""A minimal byLLM stream event, as `agent.view.render_stream` consumes them."""
obj StreamEv {
    has event_type: str,
        data: dict;
}


test "the renderer turns an event stream into the live view and turn tallies" {
    ai.agent.cfg.verbose = True;
    stream = [
        StreamEv(event_type="thought", data={"content": "Writing the file. "}),
        StreamEv(
            event_type="tool_call",
            data={"tool": "write_file", "args": {"path": "main.jac", "content": "x"}}
        ),
        StreamEv(
            event_type="tool_result", data={"result": "OK: wrote 1 chars to main.jac"}
        ),
        StreamEv(event_type="tool_timing", data={"duration_ms": 4.0}),
        StreamEv(
            event_type="tool_call",
            data={"tool": "read_file", "args": {"path": "main.jac"}}
        ),
        StreamEv(event_type="tool_result", data={"result": "x"}),
        StreamEv(
            event_type="tool_call",
            data={"tool": "run_command", "args": {"command": "ls"}}
        ),
        StreamEv(event_type="tool_result", data={"result": "main.jac"}),
        StreamEv(event_type="chunk", data={"content": "Done."}),
        StreamEv(
            event_type="usage",
            data={"total": {"prompt_tokens": 80, "completion_tokens": 12}}
        ),
        StreamEv(event_type="steps_done", data={})
    ];
    res: dict = {};
    out = capturing(lambda : res.update(ai.agent.view.render_stream(stream)));

    # Tallies: one write, one read, one run; the write armed turn_wrote.
    assert res["n_write"] == 1 , res;
    assert res["n_read"] == 1 , res;
    assert res["n_run"] == 1 , res;
    assert res["files"] == {"main.jac"} , res;
    assert res["answer"] == "Done." , res;
    assert ai.agent.turn_wrote , "a write event must arm turn_wrote";
    # The live view rendered each tool call and the answer.
    assert "write_file(path=main.jac" in out , out;
    assert "run_command(command=ls)" in out , out;
    assert "Done." in out , out;
}


test "ui sessions suppress tool error results from the live transcript" {
    ai.agent.cfg.verbose = True;
    ai.agent.bus.events = [];
    ai.agent.bus._next_id = 1;
    ai.agent.bus.active_feed = True;
    stream = [
        StreamEv(event_type="tool_call", data={"tool": "read_guide", "args": {}}),
        StreamEv(
            event_type="tool_result",
            data={
                "tool": "read_guide",
                "result": "Tool error: GuideTools.read_guide() missing 1 required positional argument: 'name'"
            }
        ),
        StreamEv(
            event_type="tool_timing", data={"tool": "read_guide", "duration_ms": 2.0}
        ),
        StreamEv(event_type="chunk", data={"content": "Recovered."}),
        StreamEv(event_type="steps_done", data={})
    ];

    events_snapshot: list = [];
    try {
        out = capturing(lambda : ai.agent.view.render_stream(stream));
        events_snapshot = list(ai.agent.bus.events);
    } finally {
        ai.agent.bus.active_feed = False;
        ai.agent.bus.events = [];
        ai.agent.bus._next_id = 1;
    }

    assert "Tool error:" not in out , out;
    assert "Recovered." in out , out;
    assert not [
        ev
        for ev in events_snapshot
        if ev.get("kind") == "tool_result" and "Tool error:" in str(ev.get("text", ""))
    ] , events_snapshot;
}


test "ui mode keeps model stream on the bus and off stdout" {
    import os;
    ai.agent.cfg.verbose = True;
    ai.agent.bus.events = [];
    ai.agent.bus._next_id = 1;
    ai.agent.bus.active_feed = True;
    prior = os.environ.get("JAC_AI_UI_ACTIVE");
    stream = [
        StreamEv(event_type="thought", data={"content": "Planning the change. "}),
        StreamEv(event_type="chunk", data={"content": "Done."}),
        StreamEv(event_type="steps_done", data={})
    ];
    events_snapshot: list = [];
    try {
        os.environ["JAC_AI_UI_ACTIVE"] = "1";
        out = capturing(lambda : ai.agent.view.render_stream(stream));
        events_snapshot = list(ai.agent.bus.events);
    } finally {
        if prior is None {
            os.environ.pop("JAC_AI_UI_ACTIVE", None);
        } else {
            os.environ["JAC_AI_UI_ACTIVE"] = prior;
        }
        ai.agent.bus.active_feed = False;
        ai.agent.bus.events = [];
        ai.agent.bus._next_id = 1;
    }

    assert out == "" , f"stdout should be empty in UI mode, got: {out!r}";
    answer_text = "".join(
        [
            str(ev.get("text", ""))
            for ev in events_snapshot
            if ev.get("kind") == "answer"
        ]
    );
    reasoning_text = "".join(
        [
            str(ev.get("text", ""))
            for ev in events_snapshot
            if ev.get("kind") == "reasoning"
        ]
    );
    assert "Done." in answer_text , events_snapshot;
    assert "Planning the change." in reasoning_text , events_snapshot;
}


test "ui mode routes tool invocations to call events for the transcript" {
    import os;
    ai.agent.cfg.verbose = True;
    ai.agent.bus.events = [];
    ai.agent.bus._next_id = 1;
    ai.agent.bus.active_feed = True;
    prior = os.environ.get("JAC_AI_UI_ACTIVE");
    stream = [
        StreamEv(
            event_type="tool_call",
            data={"tool": "read_file", "args": {"path": "main.jac"}}
        ),
        StreamEv(event_type="tool_result", data={"result": "ok"}),
        StreamEv(event_type="tool_timing", data={"duration_ms": 1.0}),
        StreamEv(event_type="chunk", data={"content": "ok"}),
        StreamEv(event_type="steps_done", data={})
    ];
    events_snapshot: list = [];
    try {
        os.environ["JAC_AI_UI_ACTIVE"] = "1";
        out = capturing(lambda : ai.agent.view.render_stream(stream));
        events_snapshot = list(ai.agent.bus.events);
    } finally {
        if prior is None {
            os.environ.pop("JAC_AI_UI_ACTIVE", None);
        } else {
            os.environ["JAC_AI_UI_ACTIVE"] = prior;
        }
        ai.agent.bus.active_feed = False;
        ai.agent.bus.events = [];
        ai.agent.bus._next_id = 1;
    }

    assert "read_file(path=main.jac" not in out , out;
    tool_calls = [
        ev
        for ev in events_snapshot
        if ev.get("kind") == "call" and str(ev.get("node", "")) == "read_file"
    ];
    assert len(tool_calls) == 1 , events_snapshot;
    assert "read_file(path=main.jac" in str(tool_calls[0].get("text", "")) , tool_calls[
        0
    ];
}


test "a scripted MockLLM drives the AgentSession walker through its phases" {
    proj = make_project();
    events: list = [];
    arm(proj, events);
    feat = str(Path(proj) / "greeting.jac");

    # One flat outputs list, consumed across phases by the shared mock cursor:
    #   Plan run_phase                -> a final answer (no tools);
    #   request_needs_code_changes    -> "true": route Plan -> Build, not the
    #                                    read-only Plan -> Done fast path;
    #   Build run_phase               -> write a compiling file, then a final answer;
    #   QA run_phase                  -> a final answer.
    # `max_steps=2` halts the walk at the step cap once QA has run, so the test
    # stays deterministic without exercising QA's LLM-driven routing (which is
    # byLLM machinery, covered elsewhere). Plan picks its successor via the typed
    # request_needs_code_changes classifier; the other phases advance along their
    # single out-edge with no model routing call.
    ai.agent_model = Model(
        model_name="mockllm",
        config={
            "outputs": [
                "Plan: add greeting.jac with a hello function.",
                "true",
                MockToolCall(
                    tool=ai.agent.files.write_file,
                    args={
                        "path": feat,
                        "content": "def hello() -> str { return \"hi\"; }\n"
                    }
                ),
                "Built greeting.jac.",
                "QA: jac check is clean."
            ]
        }
    );

    out = capturing(lambda : AgentSessionSpawn(proj));

    # The Build phase wrote the file through the real file tool.
    assert Path(feat).exists() , out;
    assert "def hello" in Path(feat).read_text();
    # The walker advanced Plan -> Build -> QA, then halted at the step cap.
    assert "Build" in out , out;
    assert "QA" in out , out;
    assert "step cap" in out , out;

    shutil.rmtree(proj, ignore_errors=True);
}


"""Spawn an AgentSession bounded to two steps so the walk halts after QA."""
def AgentSessionSpawn(objective: str) {
    ai.AgentSession(
        objective=objective, ledger=ai.Ledger(), stats=ai.TurnStats(), max_steps=2
    ) spawn root;
}
