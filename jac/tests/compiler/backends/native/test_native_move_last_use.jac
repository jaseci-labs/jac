"""A copy at a local's last use moves its reference instead of counting it.

`a = b` between locals could move only when every use of `b` was such a
copy. It now moves whenever liveness shows no path reads `b` after the copy,
as long as neither `b` nor the copy sits in a `try` (the statement graph has
no edge from a `try` body to its handlers), a lambda, a comprehension, a
`flow` or a parallel loop, and `b` is never borrowed (`&b`). The
copy then takes `b`'s reference and leaves `b` empty, whether `b`'s slot holds
an object or an optional one; `JAC_NO_MOVE_FLOW=1` turns the wider rule off.

The fixture's walks and rotation lose refcount traffic, the copies whose
source is read later keep theirs, the program prints what the Python backend
prints, and a debug build's live-object dump holds nothing at exit.
"""

import os;
import re;
import subprocess;
import tempfile;
import from tests.support { assert_native_identity, jac_command, NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "move_last_use.jac");

"""The fixture's unoptimized IR under `gc_mode`, with or without the wider moves."""
def fixture_ir(gc_mode: str, moves: bool) -> str {
    if not moves {
        os.environ["JAC_NO_MOVE_FLOW"] = "1";
    }
    try {
        prog = JacProgram();
        mod = prog.compile(
            file_path=FIXTURE, options=CompileOptions(aot_mode=True, na_gc_mode=gc_mode)
        );
    } finally {
        if not moves {
            del os.environ["JAC_NO_MOVE_FLOW"];
        }
    }
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(mod.gen.llvm_ir);
}

"""How many retains and releases function `name` emits."""
def rc_ops(text: str, name: str) -> int {
    found = re.search(r'define [^\n]*\.' + name + r'"?\(.*?\n}\n', text, re.S);
    assert found is not None , f"{name} not found in the IR";
    return len(
        re.findall(r'call void @"__rc_(retain|release)[^"]*"\(', found.group(0))
    );
}

test "a copy at the source's last use moves the reference" {
    for gc_mode in ["rc", "cycles"] {
        on = fixture_ir(gc_mode, True);
        off = fixture_ir(gc_mode, False);
        for name in ["append", "cut", "rotate", "after_call", "after_field"] {
            assert rc_ops(on, name) < rc_ops(off, name) , (
                f"{gc_mode} {name}: {rc_ops(on, name)} with moves, {rc_ops(
                    off, name
                )} without"
            );
        }
        for name in ["keep_after", "in_try"] {
            assert rc_ops(on, name) == rc_ops(off, name) , f"{gc_mode} {name} lost a count";
        }
    }
}

test "the program prints what the Python backend prints under rc and managed" {
    out = assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
    assert out.strip() == "6634" , out;
}

test "moved references are released once" {
    leak_fixture = os.path.join(NATIVE_FIXTURES, "move_last_use_leaks.jac");
    for memory in ["rc", "managed"] {
        with tempfile.TemporaryDirectory() as scratch {
            binary = os.path.join(scratch, "probe");
            comp = subprocess.run(
                jac_command(
                    "build",
                    "--native",
                    leak_fixture,
                    "--memory",
                    memory,
                    "--debug",
                    "-o",
                    binary
                ),
                capture_output=True,
                text=True,
                timeout=900
            );
            assert comp.returncode == 0 , comp.stderr[-1500:];
            proc = subprocess.run(
                [binary], capture_output=True, text=True, timeout=120
            );
            assert proc.returncode == 0 , proc.stderr[-800:];
        }
        assert proc.stdout.splitlines()[0] == "6634" , proc.stdout[:400];
        assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
        leaks = [
            line
            for line in proc.stdout.splitlines()
            if "<- LEAK" in line
        ];
        assert not leaks , f"{memory}: {leaks[:5]}";
    }
}
