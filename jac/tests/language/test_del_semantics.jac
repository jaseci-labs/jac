"""`del` semantics, per issue #8774.

Four layers: the fixture that pins every `del` form's graph and container
effect, a differential harness that replays the Python-legal forms through
CPython and asserts Jac agrees, the dead-anchor rules, and the backend-parity
checks.
"""

import ctypes;
import io;
import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT, compile_native, get_func }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures"),
     DEL_SEMANTICS = os.path.join(FIXTURES, "del_semantics.jac");

"""Run a .jac file in a subprocess and return (stdout, stderr, returncode)."""
def run_jac_file(path: str) -> tuple[str, str, int] {
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", path],
        capture_output=True,
        text=True,
        cwd=JAC_ROOT
    );
    return (result.stdout, result.stderr, result.returncode);
}

"""Write `src` to a temp .jac file, run it, and return (stdout, stderr, rc)."""
def run_jac_src(src: str) -> tuple[str, str, int] {
    fd_path = tempfile.mkstemp(suffix=".jac", prefix="del_sem_");
    os.close(fd_path[0]);
    path = fd_path[1];
    try {
        with open(path, "w") as f {
            f.write(src);
        }
        return run_jac_file(path);
    } finally {
        os.unlink(path);
    }
}

test "del semantics fixture" {
    (out, err, rc) = run_jac_file(DEL_SEMANTICS);
    assert rc == 0 , f"fixture failed:\n{err}";
    assert "del semantics: all cases ok" in out , out;
}

# ---------------------------------------------------------------------------
# Differential harness: every Python-legal `del` form must observably agree
# with CPython. The body of each case is one source text shared verbatim by
# both languages; only the import prelude and the `with entry` wrapper differ.
# ---------------------------------------------------------------------------
obj DelCase {
    has name: str,
        body: str,
        probe: str,
        py_prelude: str = "",
        jac_prelude: str = "";
}

glob NS_PY = "from types import SimpleNamespace",
     NS_JAC = "import from types { SimpleNamespace }",
     DD_PY = "from collections import defaultdict",
     DD_JAC = "import from collections { defaultdict }";

glob DEL_CASES: list[DelCase] = [
         DelCase(
             name="dict delitem",
             body='d = {"k": 1, "j": 2};\ndel d["k"];',
             probe="sorted(d.items())"
         ),
         DelCase(name="list delitem", body="L = [1, 2, 3];\ndel L[0];", probe="L"),
         DelCase(name="list slice", body="L = [1, 2, 3];\ndel L[0:2];", probe="L"),
         DelCase(
             name="list strided slice",
             body="L = [1, 2, 3, 4, 5];\ndel L[::2];",
             probe="L"
         ),
         DelCase(
             name="nested delitem", body="L = [[1, 2, 3]];\ndel L[0][1];", probe="L"
         ),
         DelCase(
             name="delattr",
             body="o = SimpleNamespace(x=1, y=2);\ndel o.x;",
             probe="sorted(vars(o).items())",
             py_prelude=NS_PY,
             jac_prelude=NS_JAC
         ),
         DelCase(
             name="tuple target",
             body="a = 1;\nb = 2;\ndel (a, b);",
             probe='("a" in globals(), "b" in globals())'
         ),
         DelCase(
             name="list target",
             body="a = 1;\nb = 2;\ndel [a, b];",
             probe='("a" in globals(), "b" in globals())'
         ),
         DelCase(name="bare name", body="x = 1;\ndel x;", probe='"x" in globals()'),
         DelCase(
             name="single element tuple target",
             body='d = {"k": 1, "j": 2};\ndel (d["k"], );',
             probe="sorted(d.items())"
         ),
         DelCase(
             name="mixed comma targets",
             body='o = SimpleNamespace(x=1, y=2);\nd = {"k": 1, "j": 2};\na = 1;\n'
             'del o.x, d["k"], a;',
             probe='(sorted(vars(o).items()), sorted(d.items()), "a" in globals())',
             py_prelude=NS_PY,
             jac_prelude=NS_JAC
         ),
         DelCase(
             name="mixed list target",
             body='o = SimpleNamespace(x=1, y=2);\nd = {"k": 1, "j": 2};\n'
             'del [d["k"], o.x];',
             probe="(sorted(vars(o).items()), sorted(d.items()))",
             py_prelude=NS_PY,
             jac_prelude=NS_JAC
         ),
         DelCase(
             name="defaultdict delitem does not trip __missing__",
             body='d = defaultdict(list);\nd["a"].append(1);\nd["b"].append(2);\n'
             'del d["a"];',
             probe="(sorted(d.items()), len(d))",
             py_prelude=DD_PY,
             jac_prelude=DD_JAC
         )
     ];

"""Run a snippet through CPython and return its stdout."""
def run_py_src(src: str) -> str {
    old = sys.stdout;
    buf = io.StringIO();
    sys.stdout = buf;
    try {
        exec(compile(src, "<del_case>", "exec"), {});
    } finally {
        sys.stdout = old;
    }
    return buf.getvalue();
}

test "del agrees with CPython on every Python-legal target" {
    for dc in DEL_CASES {
        py_src = f"{dc.py_prelude}\n{dc.body}\nprint({dc.probe})\n";
        jac_src = f"{dc.jac_prelude}\nwith entry {{\n{dc.body}\n"
        f"print({dc.probe});\n}}\n";
        expected = run_py_src(py_src);
        (out, err, rc) = run_jac_src(jac_src);
        assert rc == 0 , f"[{dc.name}] jac run failed:\n{jac_src}\n{err}";
        assert out == expected , f"[{dc.name}] jac {out!r} != cpython {expected!r}\n{jac_src}";
    }
}

# ---------------------------------------------------------------------------
# Front-end diagnostics: a malformed `del` target is caught with a location and
# a fix hint, instead of surfacing as E5043 from bytecode generation with the
# module's first line as its span.
# ---------------------------------------------------------------------------
glob BAD_TARGETS = os.path.join(FIXTURES, "del_bad_targets.jac");

"""Run `jac check` on a .jac file and return its combined output."""
def run_jac_check(path: str) -> str {
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "check", path],
        capture_output=True,
        text=True,
        cwd=JAC_ROOT
    );
    return result.stdout + result.stderr;
}

test "malformed del targets are rejected by the front end" {
    out = run_jac_check(BAD_TARGETS);
    assert out.count("error[E0083]") == 6 , out;
    assert "E5043" not in out , out;
    assert "Cannot delete a literal" in out , out;
    assert "Cannot delete an empty target list" in out , out;
    assert "Cannot delete a null-safe access" in out , out;
    assert "Cannot delete an unpacked target" in out , out;
}

test "a del value target that can never be a graph object is an error" {
    out = run_jac_check(BAD_TARGETS);
    assert out.count("error[E1133]") == 1 , out;
    assert "can never yield a graph object" in out , out;
}

test "well formed del statements never reach E5043" {
    out = run_jac_check(DEL_SEMANTICS);
    assert "E5043" not in out , out;
    assert "E0083" not in out , out;
    assert "E1133" not in out , out;
}


# ---------------------------------------------------------------------------
# Dead anchors: a destroyed object is dead, not gone. Connecting, spawning on,
# or visiting it is refused, and a walker whose queue already holds it skips
# it.
# ---------------------------------------------------------------------------
glob DEAD_ANCHOR = os.path.join(FIXTURES, "del_dead_anchor.jac");

test "a destroyed graph object is dead, not gone" {
    (out, err, rc) = run_jac_file(DEAD_ANCHOR);
    assert rc == 0 , f"fixture failed:\n{err}";
    assert "del dead anchor: all cases ok" in out , out;
}


# ---------------------------------------------------------------------------
# Backend parity: the same program, restricted to constructs the native
# backend lowers, must produce the same counts there as under the Python
# backend.
# ---------------------------------------------------------------------------
glob NATIVE_FIXTURE = "del_semantics_native.jac",
     NATIVE_EXPECTED = {
         "del_edge_ref": 0,
         "del_edge_name": 0,
         "del_node_name": 0,
         "del_traversal": 0,
         "del_subscript_destroys_node": 0,
         "del_dict_key_destroys_node": 0,
         "del_plain_subscript": 2
     };

test "del under the native backend matches the Python backend" {
    (eng, _ir) = compile_native(NATIVE_FIXTURE, fixture_dir=FIXTURES);
    for fn_name in NATIVE_EXPECTED {
        fn = get_func(eng, fn_name, ctypes.c_int64);
        assert fn() == NATIVE_EXPECTED[fn_name] , fn_name;
    }
}


# ---------------------------------------------------------------------------
# Codegen shape: a location target is peeked once through the side-effect free
# helper, destroyed non-strictly, and then released with the real Python
# `del`, which stays verbatim in the generated code. No static analysis
# decides whether the peek happens, so the lowering is the same for a typed
# and an untyped container.
# ---------------------------------------------------------------------------
glob SUBSCRIPT_IR = os.path.join(FIXTURES, "del_subscript_ir.jac");

test "a subscript del peeks once and keeps the Python del verbatim" {
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "tool", "ir", "py", SUBSCRIPT_IR],
        capture_output=True,
        text=True,
        cwd=JAC_ROOT
    );
    assert result.returncode == 0 , result.stderr;
    assert "_jac_runtime_destroy(_jac_runtime_peek_item(cache, key))"
        in result.stdout , result.stdout;
    assert "del cache[key]" in result.stdout , result.stdout;
    assert "_jac_runtime_destroy(_jac_runtime_peek_item(items, 0))" in result.stdout , result.stdout;
    assert "del items[0]" in result.stdout , result.stdout;
    assert "_jac_runtime_destroy(_jac_runtime_peek_item(items, slice(1, 3, None)))"
        in result.stdout , result.stdout;
    assert "del items[1:3]" in result.stdout , result.stdout;
    assert "strict" not in result.stdout , result.stdout;
}
