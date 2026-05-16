"""Tests for `jac guide`, the diagnostic guide hints, and the guide store.

The CLI cases invoke the command handlers in-process (the `execution.run` /
`analysis.check` pattern) with stdout and stderr captured.
"""

import io;
import json;
import os;
import shutil;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { guide, analysis, project }
import from jaclang.cli.guide_store { get_guide, list_guides, guide_for_diagnostic }

"""Absolute path to a file in the language test fixtures directory."""
def fixture_path(name: str) -> str {
    here = __file__;
    if here is None {
        raise RuntimeError("test __file__ is unavailable");
    }
    return os.path.join(os.path.dirname(here), "fixtures", name);
}

"""Invoke `jac guide` in-process; return (stdout, stderr, exit_code)."""
def run_guide(
    topic: str = "", search: str = "", export: str = "", as_json: bool = False
) -> tuple[str, str, int] {
    out = io.StringIO();
    err = io.StringIO();
    old_out = sys.stdout;
    old_err = sys.stderr;
    sys.stdout = out;
    sys.stderr = err;
    try {
        code = guide.guide(topic=topic, search=search, export=export, as_json=as_json);
    } finally {
        sys.stdout = old_out;
        sys.stderr = old_err;
    }
    return (out.getvalue(), err.getvalue(), code);
}

# --- jac guide: the CLI command ------------------------------------------------
test "jac guide lists every bundled guide" {
    (stdout, _, code) = run_guide();
    assert code == 0;
    assert "Jac reference guides" in stdout;
    assert "jac-types" in stdout;
    assert "jac-core-cheatsheet" in stdout;
}

test "jac guide <topic> prints the guide body verbatim" {
    (stdout, _, code) = run_guide(topic="jac-types");
    assert code == 0;
    assert len(stdout) > 200;
    # The body is emitted, not the raw frontmatter delimiter.
    assert not stdout.lstrip().startswith("---");
}

test "jac guide --json emits a parseable guide list" {
    (stdout, _, code) = run_guide(as_json=True);
    assert code == 0;
    parsed = json.loads(stdout);
    assert isinstance(parsed, list);
    assert len(parsed) >= 19;
    assert all("name" in g and "description" in g for g in parsed);
}

test "jac guide <topic> --json includes the guide body" {
    (stdout, _, code) = run_guide(topic="jac-types", as_json=True);
    assert code == 0;
    parsed = json.loads(stdout);
    assert parsed["name"] == "jac-types";
    assert parsed["body"] , "the single-guide JSON should carry a body";
}

test "jac guide --search filters the listing" {
    (stdout, _, code) = run_guide(search="walker");
    assert code == 0;
    assert "matching 'walker'" in stdout;
    (empty_out, _, empty_code) = run_guide(search="zzznosuchtokenzzz");
    assert empty_code == 0;
    assert "jac-types" not in empty_out , "a non-match must not list any guide";
}

test "jac guide on an unknown topic exits non-zero" {
    (_, _, code) = run_guide(topic="does-not-exist");
    assert code == 1;
}

test "jac guide --export writes a Claude Code skills directory" {
    tmp = tempfile.mkdtemp();
    try {
        (_, _, code) = run_guide(export=tmp);
        assert code == 0;
        skill = Path(tmp) / "jac-types" / "SKILL.md";
        assert skill.exists();
        content = skill.read_text(encoding="utf-8");
        assert content.startswith("---");
        assert "name: jac-types" in content;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

# --- jac check: diagnostic guide pointers --------------------------------------
test "jac check links a type error to the jac-types guide" {
    out = io.StringIO();
    err = io.StringIO();
    old_out = sys.stdout;
    old_err = sys.stderr;
    sys.stdout = out;
    sys.stderr = err;
    try {
        code = analysis.check([fixture_path("guide_hint_type_error.jac")]);
    } finally {
        sys.stdout = old_out;
        sys.stderr = old_err;
    }
    combined = out.getvalue() + err.getvalue();
    assert code == 1 , "the fixture's type error should fail the check";
    assert "jac guide jac-types" in combined , (
        "the type error should point the reader at the jac-types guide"
    );
}

# --- jac create: AGENTS.md seeding ---------------------------------------------
test "jac create seeds an AGENTS.md that points at jac guide" {
    tmp = tempfile.mkdtemp();
    old_cwd = os.getcwd();
    out = io.StringIO();
    old_out = sys.stdout;
    os.chdir(tmp);
    sys.stdout = out;
    try {
        project.create(name="proj");
    } finally {
        sys.stdout = old_out;
        os.chdir(old_cwd);
    }
    agents = Path(tmp) / "proj" / "AGENTS.md";
    assert agents.exists() , "jac create should write AGENTS.md";
    assert "jac guide" in agents.read_text(encoding="utf-8");
    shutil.rmtree(tmp, ignore_errors=True);
}

# --- guide store: library unit tests -------------------------------------------
test "guide store strips frontmatter from the guide body" {
    g = get_guide("jac-types");
    assert g is not None;
    assert g.name == "jac-types";
    assert g.description != "";
    assert not g.body.startswith("---");
    assert get_guide("does-not-exist") is None;
}

test "guide store maps diagnostic codes to guides" {
    assert guide_for_diagnostic("W0064", "syntax") == "jac-fullstack-patterns";
    assert guide_for_diagnostic("E1001", "type") == "jac-types";
    assert guide_for_diagnostic("E0001", "syntax") is None;
}

test "every bundled guide is well-formed" {
    guides = list_guides();
    assert len(guides) >= 19;
    for g in guides {
        assert g.name , "a guide is missing its name";
        assert g.description , f"guide '{g.name}' is missing a description";
        assert len(g.body) > 0 , f"guide '{g.name}' has an empty body";
    }
}
