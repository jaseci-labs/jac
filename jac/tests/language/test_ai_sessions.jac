"""Tests for `jac ai` session persistence (issue #6706).

The `SessionStore` (jac/jaclang/cli/ai_agent.jac) is JSON CRUD over a cache
dir. These tests exercise it directly against a per-test temp dir passed via
the store's `root` field, so they never touch the user's real ~/.cache/jac-ai
and are isolated from each other. No model is built -- the store is pure IO.

Slice 1 covers storage only; the ledger/cfg/cwd restore and REPL commands are
exercised in later slices via the same record shape.
"""

import io;
import json;
import os;
import shutil;
import sys;
import tempfile;
import from pathlib { Path }

import from jaclang.cli.ai_agent {
    SessionStore,
    Ledger,
    _resolve_session,
    _save_session,
    _ledger_from_dict,
    _restore_cfg,
    _print_scrollback,
    cmd_sessions,
    cmd_resume,
    cmd_name,
    cmd_forget,
    cmd_cost,
    get_session_dir,
    agent
}

"""A SessionStore rooted at a fresh temp dir, with a cleanup teardown.

Returns the store; the caller passes it to `_drop_store(root)` (or relies on
the test's `finally { shutil.rmtree(tmp) }`) to clean up.
"""
def _fresh_store -> tuple[SessionStore, str] {
    tmp = tempfile.mkdtemp(prefix="jac-ai-sess-test-");
    return (SessionStore(root_dir=tmp), tmp);
}

test "create yields a well-formed empty record" {
    (store, tmp) = _fresh_store();
    try {
        rec = store.create("/home/jac/proj", "refactor");
        assert rec["id"] and isinstance(rec["id"], str) , "id must be a non-empty string";
        assert len(rec["id"]) == 8 , f"id should be 8 hex chars, got {rec['id']}";
        assert rec["name"] == "refactor";
        assert rec["cwd"] == os.path.normpath("/home/jac/proj");
        assert rec["ledger"] == {"changes": [], "notes": []};
        assert rec["turns"] == [];
        assert rec["totals"] == {};
        assert rec["cfg"] == {};
        assert rec["created"] == rec["updated"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "save then load round-trips the record verbatim" {
    (store, tmp) = _fresh_store();
    try {
        rec = store.create("/proj", "demo");
        rec["cfg"] = {"yolo_mode": False, "model": "openai/gpt-4o", "n_ctx": 0};
        rec["ledger"] = {
            "changes": [{"phase": "Build", "summary": "added a walker"}],
            "notes": ["decided to use OSP"]
        };
        rec["turns"] = [
            {
                "objective": "add a walker",
                "phases": [
                    {"name": "Plan", "answer": "..."},
                    {"name": "Build", "answer": "done"}
                ],
                "stats": {
                    "n_read": 2,
                    "n_write": 1,
                    "n_run": 0,
                    "usage": {"prompt_tokens": 100, "completion_tokens": 40}
                }
            }
        ];
        rec["totals"] = {
            "prompt_tokens": 100,
            "completion_tokens": 40,
            "n_read": 2,
            "n_write": 1
        };
        store.save(rec);

        loaded = store.load(rec["id"]);
        assert loaded is not None , "load must return the saved record";
        assert loaded["id"] == rec["id"];
        assert loaded["name"] == "demo";
        assert loaded["cfg"] == rec["cfg"];
        assert loaded["ledger"] == rec["ledger"];
        assert loaded["turns"] == rec["turns"];
        assert loaded["totals"] == rec["totals"];
        # save stamps `updated`; it must be present and iso-formatted.
        assert loaded["updated"] and "T" in loaded["updated"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "load returns None for a missing id (no raise)" {
    (store, tmp) = _fresh_store();
    try {
        assert store.load("deadbeef") is None;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "load returns None for an empty id" {
    (store, tmp) = _fresh_store();
    try {
        assert store.load("") is None;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "load is resilient to corrupt JSON (returns None, does not raise)" {
    (store, tmp) = _fresh_store();
    try {
        # Plant a malformed session file directly.
        corrupt_path = store._path("badfile1");
        Path(corrupt_path).write_text("{ this is not : valid json ]", encoding="utf-8");
        loaded = store.load("badfile1");
        assert loaded is None , "corrupt JSON must yield None, not an exception";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "save is atomic -- a corrupt/partial file is never left behind" {
    (store, tmp) = _fresh_store();
    try {
        rec = store.create("/proj", "atomic");
        store.save(rec);
        # A successful save writes the final file and no leftover .tmp.
        final_path = store._path(rec["id"]);
        assert os.path.exists(final_path) , "final file must exist after save";
        assert not os.path.exists(f"{final_path}.tmp") , "no temp file must linger";
        # The written file must be valid JSON (parseable).
        with open(final_path, "r", encoding="utf-8") as f {
            json.load(f);
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "list_sessions returns newest-first by updated" {
    (store, tmp) = _fresh_store();
    try {
        a = store.create("/proj", "a");
        b = store.create("/proj", "b");
        c = store.create("/proj", "c");
        store.save(a);
        store.save(b);
        store.save(c);
        ids = [r["id"] for r in store.list_sessions()];
        assert ids == [c["id"], b["id"], a["id"]] , (
            f"expected newest-first [c, b, a], got {ids}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "list_sessions filters by cwd (isolation across projects)" {
    (store, tmp) = _fresh_store();
    try {
        p1 = store.create("/home/jac/proj-one", "one");
        p2 = store.create("/home/jac/proj-two", "two");
        store.save(p1);
        store.save(p2);
        one = store.list_sessions(cwd="/home/jac/proj-one");
        two = store.list_sessions(cwd="/home/jac/proj-two");
        assert len(one) == 1 and one[0]["id"] == p1["id"];
        assert len(two) == 1 and two[0]["id"] == p2["id"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "list_sessions normalizes cwd so trailing slashes match" {
    (store, tmp) = _fresh_store();
    try {
        rec = store.create("/home/jac/proj", "x");
        store.save(rec);
        matches = store.list_sessions(cwd="/home/jac/proj/");
        assert len(matches) == 1 and matches[0]["id"] == rec["id"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "list_sessions skips corrupt files (one bad file doesn't hide the rest)" {
    (store, tmp) = _fresh_store();
    try {
        good = store.create("/proj", "good");
        store.save(good);
        Path(store._path("badfile2")).write_text("not json", encoding="utf-8");
        listing = store.list_sessions(cwd="/proj");
        assert len(listing) == 1 and listing[0]["id"] == good["id"] , (
            "the good session must survive a corrupt sibling"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "most_recent returns the newest session for a cwd, or None" {
    (store, tmp) = _fresh_store();
    try {
        assert store.most_recent("/proj") is None;
        first = store.create("/proj", "first");
        store.save(first);
        # A sleep-free ordering guarantee: most_recent re-sorts by `updated`,
        # so saving a second session makes it the newest regardless of clock
        # resolution (both share the same second -- ties broken by list order).
        second = store.create("/proj", "second");
        store.save(second);
        mr = store.most_recent("/proj");
        assert mr is not None and mr["id"] == second["id"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "resolve_by_name finds an existing named session for a cwd" {
    (store, tmp) = _fresh_store();
    try {
        rec = store.create("/proj", "refactor-walker");
        store.save(rec);
        hit = store.resolve_by_name("/proj", "refactor-walker");
        assert hit is not None and hit["id"] == rec["id"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "resolve_by_name misses when no name matches" {
    (store, tmp) = _fresh_store();
    try {
        rec = store.create("/proj", "refactor-walker");
        store.save(rec);
        assert store.resolve_by_name("/proj", "nope") is None;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "resolve_by_name is scoped to a cwd (same name in two projects)" {
    (store, tmp) = _fresh_store();
    try {
        a = store.create("/proj-a", "shared");
        b = store.create("/proj-b", "shared");
        store.save(a);
        store.save(b);
        hit_a = store.resolve_by_name("/proj-a", "shared");
        hit_b = store.resolve_by_name("/proj-b", "shared");
        assert hit_a is not None and hit_a["id"] == a["id"];
        assert hit_b is not None and hit_b["id"] == b["id"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "resolve_by_name returns None for an empty name" {
    (store, tmp) = _fresh_store();
    try {
        assert store.resolve_by_name("/proj", "") is None;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "delete removes a session's file" {
    (store, tmp) = _fresh_store();
    try {
        rec = store.create("/proj", "gone");
        store.save(rec);
        assert store.load(rec["id"]) is not None;
        assert store.delete(rec["id"]) is True;
        assert store.load(rec["id"]) is None;
        assert store.delete(rec["id"]) is False , "second delete: no file to remove";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "delete on an empty id is a no-op returning False" {
    (store, tmp) = _fresh_store();
    try {
        assert store.delete("") is False;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "created ids are unique across calls" {
    (store, tmp) = _fresh_store();
    try {
        ids = {store.create("/proj")["id"] for _ in range(50)};
        assert len(ids) == 50 , "token_hex must produce unique ids";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "lazy root honors the JAC_AI_CACHE env override" {
    # A store with root="" resolves the cache dir at call time, so setting
    # JAC_AI_CACHE after construction still takes effect.
    tmp = tempfile.mkdtemp(prefix="jac-ai-env-test-");
    old = os.environ.get("JAC_AI_CACHE");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        store = SessionStore();  # root left at default ""
        rec = store.create("/proj", "env");
        store.save(rec);
        # The file must land under the env-overridden dir.
        assert Path(tmp, "sessions", f"{rec['id']}.json").exists();
    } finally {
        if old is None {
            del os.environ["JAC_AI_CACHE"];
        } else {
            os.environ["JAC_AI_CACHE"] = old;
        }
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "default cache dir routes through the centralized resolver" {
    # Sessions must share the jac cache root with the JIR cache (centralized
    # in #6709), not live in a parallel ~/.cache/jac-ai tree.
    import from jaclang.jac0core.cache_paths {
        get_ai_session_cache_dir,
        get_jir_cache_dir
    }
    old = os.environ.get("JAC_AI_CACHE");
    os.environ.pop("JAC_AI_CACHE", None);
    try {
        default = get_session_dir();
        central = str(get_ai_session_cache_dir());
        assert default == central , "get_session_dir must delegate to cache_paths";
        assert Path(default).parent == Path(str(get_jir_cache_dir())).parent , "sessions and JIR cache must share a root";
    } finally {
        if old is None {
            os.environ.pop("JAC_AI_CACHE", None);
        } else {
            os.environ["JAC_AI_CACHE"] = old;
        }
    }
}


test "JAC_AI_CACHE override beats the centralized default" {
    import from jaclang.jac0core.cache_paths { get_ai_session_cache_dir }
    tmp = tempfile.mkdtemp(prefix="jac-ai-override-");
    old = os.environ.get("JAC_AI_CACHE");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        assert get_session_dir() == tmp , "override must win";
        assert tmp != str(get_ai_session_cache_dir());
    } finally {
        if old is None {
            os.environ.pop("JAC_AI_CACHE", None);
        } else {
            os.environ["JAC_AI_CACHE"] = old;
        }
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ---------------------------------------------------------------------------
# Slice 3 -- session lifecycle (resolve / restore / save) against the live
# `agent` glob. These exercise the bridge between the on-disk record and the
# in-memory ledger/cfg, without a real model. They mutate module globals
# (`agent`, `_session_*`, `JAC_AI_CACHE`), so each saves and restores prior
# state in a `finally` to stay isolated from the rest of the suite.
# ---------------------------------------------------------------------------
"""A minimal request-shaped object for _resolve_session (avoids importing
AgentRequest, which would pull in CodeIntelligence setup)."""
obj ResolveReq {
    has resume: str = "",
        continue_last: bool = False,
        session_name: str = "",
        model: str = "",
        n_ctx: int = 0;
}

"""Snapshot the globals the lifecycle tests mutate, to restore afterward.

Goes through the module object (sys.modules) rather than `global` rebinds,
because `_resolve_session`/`_save_session` rebind `_session_record` on the
ai_agent module -- a `global` in this test module would touch a different
namespace and silently leak state between tests.
"""
def _ai_mod -> any {
    return sys.modules["jaclang.cli.ai_agent"];
}

def _snapshot_state -> tuple {
    m = _ai_mod();
    return (
        m.agent.ledger,
        m.agent.cfg.verbose,
        m.agent.cfg.show_stats,
        m.agent.ws.cwd,
        os.environ.get("JAC_AI_CACHE"),
        m._session_store,
        dict(m._session_record)
    );
}

def _restore_state(snap: tuple) {
    m = _ai_mod();
    (ledger, verbose, show_stats, cwd, old_cache, old_store, old_rec) = snap;
    m.agent.ledger = ledger;
    m.agent.cfg.verbose = verbose;
    m.agent.cfg.show_stats = show_stats;
    m.agent.ws.cwd = cwd;
    if old_cache is None {
        os.environ.pop("JAC_AI_CACHE", None);
    } else {
        os.environ["JAC_AI_CACHE"] = old_cache;
    }
    m._session_store = old_store;
    m._session_record = old_rec;
}

test "resolve with no selectors starts a fresh unnamed session" {
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        assert _resolve_session(ResolveReq()) is True;
        rec = _ai_mod()._session_record;
        assert rec["cwd"] == os.path.normpath("/proj");
        assert rec["name"] == "" , "no selector means unnamed";
        assert rec["turns"] == [];
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "two selectors are rejected (mutual exclusivity)" {
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        assert _resolve_session(
            ResolveReq(resume="abc123", continue_last=True)
        ) is False;
        assert _resolve_session(ResolveReq(resume="abc123", session_name="x")) is False;
        assert _resolve_session(
            ResolveReq(continue_last=True, session_name="x")
        ) is False;
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "save then continue restores the ledger across a simulated restart" {
    # The slice-3 milestone: a ledger note + change added in one "process" is
    # visible after resolve+restore in a fresh state via --continue.
    import from jaclang.cli.ai_agent { Ledger }
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        _resolve_session(ResolveReq());
        m = _ai_mod();
        saved_id = m._session_record["id"];
        # Seed the cross-turn memory exactly as a real turn would.
        agent.ledger = Ledger();
        agent.ledger.remember("decided to use OSP for the walker");
        agent.ledger.record("Build", "added a walker node");
        _save_session("add a walker", None);

        # Simulated restart: drop in-memory state, resolve via --continue.
        agent.ledger = None;
        agent.ws.cwd = "/proj";
        assert _resolve_session(ResolveReq(continue_last=True)) is True;
        m = _ai_mod();
        assert m._session_record["id"] == saved_id , "--continue must pick the same session";
        # Restore exactly as run_agent does on the resume path.
        agent.ledger = _ledger_from_dict(m._session_record["ledger"]);
        assert len(agent.ledger.changes) == 1;
        assert agent.ledger.changes[0]["phase"] == "Build";
        assert "OSP" in agent.ledger.notes[0];
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "save folds per-turn stats into running totals" {
    # Two synthetic turns accumulate token + tool counts in record.totals.
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        _resolve_session(ResolveReq());

        def fake_stats(n_read: int, n_write: int, prompt: int, completion: int) {
            return type(
                "S",
                (),
                {
                    "n_read": n_read,
                    "n_write": n_write,
                    "n_run": 0,
                    "usage": {"prompt_tokens": prompt, "completion_tokens": completion}
                }
            )();
        }
        _save_session("turn one", fake_stats(2, 1, 100, 40));
        _save_session("turn two", fake_stats(3, 2, 200, 60));
        totals = _ai_mod()._session_record["totals"];
        assert totals["n_read"] == 5 , f"expected 5 reads, got {totals.get('n_read')}";
        assert totals["n_write"] == 3;
        assert totals["prompt_tokens"] == 300;
        assert totals["completion_tokens"] == 100;
        assert len(_ai_mod()._session_record["turns"]) == 2;
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "restore_cfg only writes keys present in the record" {
    # An old session file missing a field must not clobber the live default.
    snap = _snapshot_state();
    try {
        agent.cfg.verbose = True;
        agent.cfg.show_stats = True;
        # Record carries verbose but not show_stats.
        _restore_cfg({"cfg": {"verbose": False}});
        assert agent.cfg.verbose is False , "present key must be restored";
        assert agent.cfg.show_stats is True , "missing key must keep its live value";
    } finally {
        _restore_state(snap);
    }
}

test "resume by id misses cleanly when the id does not exist" {
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        # A bogus resume id resolves to a fresh session (resolve returns True;
        # the record is new and empty), so the agent still runs.
        assert _resolve_session(ResolveReq(resume="deadbeef")) is True;
        rec = _ai_mod()._session_record;
        assert rec["turns"] == [];
        assert rec["id"] != "deadbeef";
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ---------------------------------------------------------------------------
# Slice 4 -- transcript capture (per-turn phases) + scrollback rendering.
# ---------------------------------------------------------------------------
test "save captures per-turn phase answers in the turn record" {
    import from jaclang.cli.ai_agent { _session_record }
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        _resolve_session(ResolveReq());
        phases = [
            {"name": "Plan", "answer": "I will add a walker."},
            {"name": "Build", "answer": "Created walker Greeter."},
            {"name": "QA", "answer": "jac check passed."}
        ];
        def stats_with(reads: int) {
            return type(
                "S", (), {"n_read": reads, "n_write": 0, "n_run": 0, "usage": {}}
            )();
        }
        _save_session("add a walker", stats_with(2), phases);
        rec = _ai_mod()._session_record;
        assert len(rec["turns"]) == 1;
        turn = rec["turns"][0];
        assert turn["objective"] == "add a walker";
        assert turn["phases"] == phases , "phase transcript must persist verbatim";
        # The last phase's answer is what scrollback shows.
        assert turn["phases"][-1]["name"] == "QA";
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "save with no phases stores an empty phases list (back-compat)" {
    # A turn saved before transcript capture (or a stats-only save) must not
    # break scrollback: phases is always a list, never missing.
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        _resolve_session(ResolveReq());
        def s {
            return type(
                "S", (), {"n_read": 1, "n_write": 0, "n_run": 0, "usage": {}}
            )();
        }
        _save_session("stats only", s(), None);
        turn = _ai_mod()._session_record["turns"][0];
        assert turn["phases"] == [];
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "scrollback renders nothing for an empty record" {
    captured = io.StringIO();
    old = sys.stdout;
    sys.stdout = captured;
    try {
        _print_scrollback({"turns": []});
        _print_scrollback({});
    } finally {
        sys.stdout = old;
    }
    assert captured.getvalue() == "" , "empty records must render nothing";
}

test "scrollback renders each turn's objective and last phase answer" {
    # A populated record prints the header + one line per turn (objective) plus
    # an excerpt of the final phase's answer. We assert substrings, not exact
    # styling, so this is stable against console changes.
    captured = io.StringIO();
    old = sys.stdout;
    sys.stdout = captured;
    try {
        _print_scrollback(
            {
                "id": "abcd1234",
                "name": "refactor",
                "cwd": "/home/jac/proj",
                "turns": [
                    {
                        "objective": "add a walker to main.jac",
                        "phases": [
                            {"name": "Plan", "answer": "planning"},
                            {"name": "QA", "answer": "jac check passed cleanly"}
                        ]
                    },
                    {
                        "objective": "make it greet by name",
                        "phases": [{"name": "Build", "answer": "added a name field"}]
                    }
                ]
            }
        );
    } finally {
        sys.stdout = old;
    }
    out = captured.getvalue();
    assert "refactor" in out , "header must name the session";
    assert "2 prior turn(s)" in out;
    assert "add a walker to main.jac" in out;
    assert "make it greet by name" in out;
    assert "jac check passed cleanly" in out , "last phase answer must show";
    assert "added a name field" in out;
}

test "scrollback tolerates a turn with no phases" {
    captured = io.StringIO();
    old = sys.stdout;
    sys.stdout = captured;
    try {
        _print_scrollback(
            {"turns": [{"objective": "orphan turn with no phases", "phases": []}]}
        );
    } finally {
        sys.stdout = old;
    }
    out = captured.getvalue();
    assert "orphan turn with no phases" in out;
    assert "not defined" not in out , "must not raise on missing phase answers";
}


# ---------------------------------------------------------------------------
# Slice 5 -- REPL session-management commands (/sessions, /resume, /name,
# /forget, /cost) and /clear wipe-and-stay.
# ---------------------------------------------------------------------------

# Captures stdout AND stderr while `body` runs, returns the merged text.
# console.error writes to sys.stderr (see console.impl.jac), so a stdout-only
# swap would miss error messages. Restores both streams in a finally.
def _capture(body: any) -> str {
    captured = io.StringIO();
    old_out = sys.stdout;
    old_err = sys.stderr;
    sys.stdout = captured;
    sys.stderr = captured;
    try {
        body();
    } finally {
        sys.stdout = old_out;
        sys.stderr = old_err;
    }
    return captured.getvalue();
}


# A fake resolve-request object shaped like AgentRequest: only the fields
# _resolve_session reads (resume/continue_last/session_name) need to exist.
def _req {
    return ResolveReq();
}


def _fake_stats(reads: int) -> any {
    return type("S", (), {"n_read": reads, "n_write": 0, "n_run": 0, "usage": {}})();
}


test "/name names the current session and persists to disk" {
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        _resolve_session(_req());
        cmd_name("refactor");
        rec = _ai_mod()._session_record;
        assert rec["name"] == "refactor";
        # The name survives a fresh load from disk.
        loaded = _ai_mod()._session_store.load(rec["id"]);
        assert loaded is not None and loaded["name"] == "refactor";
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "/name with no arg shows the current name" {
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        _resolve_session(_req());
        cmd_name("thename");
        out = _capture(lambda() : cmd_name(""));
        assert "thename" in out , "bare /name must echo the current name";
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "/name rejects a name already used by another session in this cwd" {
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        # Session A: claim the name.
        _resolve_session(_req());
        cmd_name("taken");
        a_id = _ai_mod()._session_record["id"];
        # Session B (different id): must not steal the name.
        _resolve_session(_req());
        b_id = _ai_mod()._session_record["id"];
        assert b_id != a_id;
        out = _capture(lambda() : cmd_name("taken"));
        assert "already used" in out , "collision must be reported";
        # B's name must be unchanged (still unset).
        assert _ai_mod()._session_record.get("name", "") in ("", None);
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "/resume switches by id and by name, and misses cleanly" {
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        # Session A: named, with a remembered change.
        _resolve_session(_req());
        cmd_name("alpha");
        a_id = _ai_mod()._session_record["id"];
        agent.ledger = Ledger();
        agent.ledger.record("Build", "added a walker");
        _save_session("turn one", _fake_stats(1), [{"name": "QA", "answer": "ok"}]);
        # Session B: the active one after this resolve. A fresh resolve in
        # run_agent would hit reset_session(); simulate that here so B starts
        # with an empty ledger, then prove /resume restores A's.
        _resolve_session(_req());
        agent.ledger = Ledger();
        assert _ai_mod()._session_record["id"] != a_id;
        assert len(agent.ledger.changes) == 0 , "B starts clean";
        # Switch back by name -- ledger must restore.
        cmd_resume("alpha");
        assert _ai_mod()._session_record["id"] == a_id;
        assert len(agent.ledger.changes) == 1 , "A's ledger must be restored";
        # Switch by id too.
        _resolve_session(_req());
        cmd_resume(a_id);
        assert _ai_mod()._session_record["id"] == a_id;
        # Miss reports an error and leaves the current session active.
        out = _capture(lambda() : cmd_resume("nope"));
        assert "no session" in out;
        assert _ai_mod()._session_record["id"] == a_id;
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "/sessions lists sessions and marks the current one" {
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        _resolve_session(_req());
        cmd_name("alpha");
        _resolve_session(_req());
        _save_session();  # persist B so it shows in the listing
        b_id = _ai_mod()._session_record["id"];
        out = _capture(lambda() : cmd_sessions());
        assert "sessions in /proj" in out;
        assert "alpha" in out;
        # The current (B) row is marked with a leading '*'.
        star_line = [
            ln
            for ln in out.splitlines()
            if b_id in ln
        ][0];
        assert star_line.strip().startswith("*") , "current session marked with *";
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "/cost reports cumulative tokens and tool counts" {
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        _resolve_session(_req());
        def st {
            return type(
                "S",
                (),
                {
                    "n_read": 3,
                    "n_write": 2,
                    "n_run": 1,
                    "usage": {"prompt_tokens": 500, "completion_tokens": 120}
                }
            )();
        }
        _save_session("turn one", st(), [{"name": "QA", "answer": "ok"}]);
        out = _capture(lambda() : cmd_cost());
        assert "500 in" in out , "prompt tokens must show";
        assert "120 out" in out , "completion tokens must show";
        assert "3 read" in out and "2 write" in out and "1 run" in out;
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "/forget deletes the session file and starts a fresh one" {
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        _resolve_session(_req());
        _save_session();  # persist so the file genuinely exists before delete
        old_id = _ai_mod()._session_record["id"];
        # Auto-confirm the destructive prompt.
        _ai_mod().confirm = lambda x : True ;
        cmd_forget();
        new_id = _ai_mod()._session_record["id"];
        assert new_id != old_id , "a fresh session must be allocated";
        old_path = os.path.join(tmp, "sessions", f"{old_id}.json");
        assert not os.path.exists(old_path) , "old session file must be deleted";
        new_path = os.path.join(tmp, "sessions", f"{new_id}.json");
        assert os.path.exists(new_path) , "fresh session file must exist";
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "/forget cancelled by the user leaves the session intact" {
    snap = _snapshot_state();
    tmp = tempfile.mkdtemp(prefix="jac-ai-life-");
    os.environ["JAC_AI_CACHE"] = tmp;
    try {
        agent.ws.cwd = "/proj";
        _resolve_session(_req());
        _save_session();  # persist the shell so the file exists on disk
        old_id = _ai_mod()._session_record["id"];
        _ai_mod().confirm = lambda x : False ;  # user says no
        out = _capture(lambda() : cmd_forget());
        assert "cancelled" in out;
        assert _ai_mod()._session_record["id"] == old_id , "session must survive a cancel";
        assert os.path.exists(os.path.join(tmp, "sessions", f"{old_id}.json")) , "file must survive a cancel";
    } finally {
        _restore_state(snap);
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
