"""Tests for `jac code`, the compiler-backed code-intelligence CLI.

Each case invokes the command handler in-process (the `run_guide` pattern from
test_guide.jac) against a throwaway fixture project, with stdout/stderr
captured. The fixture is a minimal but complete project -- a node, an obj that
references it, and a walker that visits it -- so every subcommand has real
structure to report. `jac code` autodiscovers the project root from the cwd,
so the runner chdirs into the fixture for the call.
"""

import io;
import json;
import os;
import shutil;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { code }

# A minimal, clean (zero-diagnostic) project exercising every query surface.
glob _FIXTURE = """
node Widget {
    has size: int = 0;
}

obj Gadget {
    has widget: Widget;
    has label: str = "";
}

walker Inspector {
    can look with Widget entry {
        visit [-->];
    }
}

def build_gadget(w: Widget) -> Gadget {
    return Gadget(label="g", widget=w);
}
""";


"""Create a throwaway project rooted at a fresh tempdir; return its path."""
def make_project -> str {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "jac.toml").write_text(
        "[project]\nname = \"codetest\"\n", encoding="utf-8"
    );
    (Path(tmp) / "main.jac").write_text(_FIXTURE, encoding="utf-8");
    return tmp;
}


"""Invoke `jac code` in-process from inside `proj`; return (stdout, stderr, code)."""
def run_code(
    proj: str, action: str = "", target: str = "", text: bool = False, depth: int = 1
) -> tuple[str, str, int] {
    out = io.StringIO();
    err = io.StringIO();
    old_out = sys.stdout;
    old_err = sys.stderr;
    old_cwd = os.getcwd();
    sys.stdout = out;
    sys.stderr = err;
    os.chdir(proj);
    try {
        rc = code.code(action=action, target=target, text=text, depth=depth);
    } finally {
        sys.stdout = old_out;
        sys.stderr = old_err;
        os.chdir(old_cwd);
    }
    return (out.getvalue(), err.getvalue(), rc);
}


# --- map -----------------------------------------------------------------------
test "jac code map reports every archetype as versioned JSON" {
    proj = make_project();
    try {
        (stdout, _, rc) = run_code(proj, action="map");
        assert rc == 0;
        payload = json.loads(stdout);
        assert payload["schema_version"] == 1;
        assert payload["command"] == "map";
        names = {a["name"]: a["kind"] for a in payload["archetypes"]};
        assert names["Widget"] == "node";
        assert names["Gadget"] == "obj";
        assert names["Inspector"] == "walker";
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

test "jac code map <kind> filters to one archetype kind" {
    proj = make_project();
    try {
        (stdout, _, rc) = run_code(proj, action="map", target="walker");
        assert rc == 0;
        payload = json.loads(stdout);
        kinds = {a["kind"] for a in payload["archetypes"]};
        assert kinds == {"walker"};
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

test "jac code map --text renders human-readable rows" {
    proj = make_project();
    try {
        (stdout, _, rc) = run_code(proj, action="map", text=True);
        assert rc == 0;
        assert "Widget" in stdout;
        # Text mode must not emit the JSON envelope.
        assert "schema_version" not in stdout;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

# --- symbol --------------------------------------------------------------------
test "jac code symbol resolves a definition with its fields" {
    proj = make_project();
    try {
        (stdout, _, rc) = run_code(proj, action="symbol", target="Gadget");
        assert rc == 0;
        payload = json.loads(stdout);
        assert len(payload["definitions"]) == 1;
        defn = payload["definitions"][0];
        assert defn["name"] == "Gadget";
        assert defn["kind"] == "obj";
        assert any("label" in f for f in defn["fields"]);
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

test "jac code symbol on an unknown name exits 2 with empty JSON" {
    proj = make_project();
    try {
        (stdout, _, rc) = run_code(proj, action="symbol", target="Nonexistent");
        assert rc == 2;
        payload = json.loads(stdout);
        assert payload["definitions"] == [];
        assert payload["uses"] == [];
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

# --- uses ----------------------------------------------------------------------
test "jac code uses lists def/use references for a symbol" {
    proj = make_project();
    try {
        (stdout, _, rc) = run_code(proj, action="uses", target="Widget");
        assert rc == 0;
        payload = json.loads(stdout);
        roles = {r["role"] for r in payload["references"]};
        assert "def" in roles , "the definition site must appear in references";
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

# --- walkers -------------------------------------------------------------------
test "jac code walkers finds entry points that visit a node type" {
    proj = make_project();
    try {
        (stdout, _, rc) = run_code(proj, action="walkers", target="Widget");
        assert rc == 0;
        payload = json.loads(stdout);
        walkers = {ep["walker_name"] for ep in payload["entry_points"]};
        assert "Inspector" in walkers;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

# --- slice ---------------------------------------------------------------------
test "jac code slice packs a symbol with its type dependencies" {
    proj = make_project();
    try {
        (stdout, _, rc) = run_code(proj, action="slice", target="Gadget", depth=1);
        assert rc == 0;
        payload = json.loads(stdout);
        sl = payload["slice"];
        assert sl["target"]["name"] == "Gadget";
        # Gadget has a `widget: Widget` field, so Widget is a depth-1 dependency.
        related = {s["name"] for s in sl["related"]};
        assert "Widget" in related;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

# --- diag ----------------------------------------------------------------------
test "jac code diag reports a clean project with zero errors" {
    proj = make_project();
    try {
        (stdout, _, rc) = run_code(proj, action="diag");
        assert rc == 0;
        payload = json.loads(stdout);
        assert payload["error_count"] == 0;
        assert isinstance(payload["diagnostics"], list);
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

# --- usage / error paths -------------------------------------------------------
test "jac code with no action prints the discovery surface" {
    proj = make_project();
    try {
        (stdout, _, rc) = run_code(proj);
        assert rc == 0;
        assert "ask the compiler about your code" in stdout;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

test "jac code with an unknown action exits 1 with a JSON error" {
    proj = make_project();
    try {
        (stdout, _, rc) = run_code(proj, action="frobnicate");
        assert rc == 1;
        payload = json.loads(stdout);
        assert "error" in payload;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}

test "jac code symbol without a target exits 1" {
    proj = make_project();
    try {
        (_, _, rc) = run_code(proj, action="symbol");
        assert rc == 1;
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
}
