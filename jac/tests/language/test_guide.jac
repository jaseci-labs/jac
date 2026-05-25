"""Tests for `jac guide`, the diagnostic guide hints, and the guide store.

The CLI cases invoke the command handlers in-process (the `execution.run` /
`analysis.check` pattern) with stdout and stderr captured.
"""

import io;
import json;
import os;
import re;
import shutil;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { guide, analysis, project }
import from jaclang.cli.guide_store { get_guide, list_guides, guide_for_diagnostic }
import from jaclang.project.template_registry { initialize_template_registry }

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
test "jac create includes an AGENTS.md in every new project" {
    # Register the built-in templates the way the CLI bootstrap does.
    initialize_template_registry();
    tmp = tempfile.mkdtemp();
    old_cwd = os.getcwd();
    out = io.StringIO();
    old_out = sys.stdout;
    os.chdir(tmp);
    sys.stdout = out;
    try {
        code = project.create(name="proj");
    } finally {
        sys.stdout = old_out;
        os.chdir(old_cwd);
    }
    assert code == 0 , "jac create should succeed";
    agents = Path(tmp) / "proj" / "AGENTS.md";
    assert agents.exists() , "every created project must include AGENTS.md";
    assert "jac guide" in agents.read_text(encoding="utf-8");
    shutil.rmtree(tmp, ignore_errors=True);
}

test "AGENTS.md seeding never clobbers a project's existing file" {
    tmp = tempfile.mkdtemp();
    try {
        assert project._seed_agent_guide(Path(tmp), False);
        # A second seed must leave the existing AGENTS.md untouched.
        assert not project._seed_agent_guide(Path(tmp), False);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
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
    # Type-category diagnostics route to the jac-types guide via the
    # category fallback; codes with no mapping return None.
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

# --- guide examples: verify code blocks against the live compiler --------------
#
# Convention: a fenced block opened with exactly ```jac is a complete, runnable
# example and MUST pass `jac check`. A non-runnable prose fragment uses a plain
# ``` fence (the guides' existing style for snippets) and is left unchecked --
# prefer a self-contained ```jac example wherever it is practical.
"""Extract the bodies of every ```jac-fenced block from a guide body.

Only the exact ```jac fence is collected; plain ``` fragments and every other
fence (```toml, ```css, ...) are skipped.
"""
def jac_code_blocks(body: str) -> list[str] {
    blocks: list[str] = [];
    buf: list[str] = [];
    in_jac: bool = False;
    in_other: bool = False;
    for raw in body.split("\n") {
        line = raw.rstrip();
        s = line.strip();
        if not in_jac and not in_other {
            if s == "```jac" {
                in_jac = True;
                buf = [];
            } elif s.startswith("```") {
                in_other = True;
            }
        } elif in_jac {
            if s == "```" {
                blocks.append("\n".join(buf));
                in_jac = False;
            } else {
                buf.append(line);
            }
        } elif s == "```" {
            in_other = False;
        }
    }
    return blocks;
}

"""Pick the file extension a guide example should be checked under.

Client examples render JSX; server examples expose def:pub/def:priv endpoints
without JSX; everything else is plain Jac.
"""
def guide_block_ext(code: str) -> str {
    if "JsxElement" in code or "/>" in code or "</" in code {
        return ".cl.jac";
    }
    if "def:pub" in code or "def:priv" in code or "walker:pub" in code {
        return ".sv.jac";
    }
    return ".jac";
}

"""Run `analysis.check` on a guide example; return (exit_code, captured_output)."""
def check_guide_block(code: str) -> tuple[int, str] {
    (fd, path) = tempfile.mkstemp(suffix=guide_block_ext(code));
    os.close(fd);
    Path(path).write_text(code + "\n", encoding="utf-8");
    out = io.StringIO();
    err = io.StringIO();
    old_out = sys.stdout;
    old_err = sys.stderr;
    sys.stdout = out;
    sys.stderr = err;
    try {
        # nowarn: guide examples may warn (unresolved @jac/runtime imports in
        # standalone .cl.jac, etc.) -- only hard errors should fail a guide.
        rc = analysis.check([path], print_errs=True, nowarn=True);
    } finally {
        sys.stdout = old_out;
        sys.stderr = old_err;
        os.remove(path);
    }
    return (rc, out.getvalue() + err.getvalue());
}

test "every ```jac example in a guide checks clean" {
    failures: list[str] = [];
    for g in list_guides() {
        idx = 0;
        for code in jac_code_blocks(g.body) {
            idx += 1;
            (rc, output) = check_guide_block(code);
            if rc != 0 {
                failures.append(f"--- {g.name} block #{idx} ---\n{output}");
            }
        }
    }
    assert not failures , (
        "guide ```jac examples must pass `jac check` -- fix the example, or " + "if it is a non-runnable fragment downgrade its fence to plain ```:\n\n" + "\n".join(
            failures
        )
    );
}

test "guides only reference known jac create templates" {
    # `default` ships with jaclang; `client` / `fullstack` are registered by the
    # jac-client plugin. A guide naming anything else is a typo or stale name.
    # (Allowlist, not the live registry: plugin templates are absent unless the
    # plugin is installed, so the registry alone would flag a correct guide.)
    known: list[str] = ["default", "client", "fullstack"];
    bad: list[str] = [];
    for g in list_guides() {
        # Capture bare template names only; skip path/URL forms (./x.jacpack,
        # https://...) via the trailing negative lookahead.
        for m in re.findall(
            r"jac create[^`\n]*?--use\s+([A-Za-z0-9_-]+)(?![\w:/.-])", g.body
        ) {
            if m not in known {
                bad.append(f"{g.name}: `jac create --use {m}` -- unknown template");
            }
        }
    }
    assert not bad , (
        f"guides reference templates outside {known}:\n" + "\n".join(bad)
    );
}
