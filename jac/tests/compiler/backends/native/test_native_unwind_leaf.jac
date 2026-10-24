"""Exception support costs a frame little until something raises.

A frame that owns rc locals links an unwind record so a raise crossing it
releases them. A frame that can raise while holding one only through its own
`raise` statements and checks (every call that can raise runs while its
locals are still null) now links none and releases its locals at those raise
sites instead. A frame that does link one, and every `try`, fetch the thread's
exception context through an always-inlined fast path rather than a call to
the shared weak lookup, and a `try` in a program that never entered a region
reads one flag instead of calling for the region depth.

The fixture agrees with the Python backend, and a debug build's live-object
dump holds nothing at exit but the global table.
"""

import os;
import re;
import subprocess;
import tempfile;
import from tests.support { assert_native_identity, jac_command, NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "unwind_leaf.jac");

"""The fixture's unoptimized IR under `gc_mode`."""
def fixture_ir(gc_mode: str) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=FIXTURE, options=CompileOptions(aot_mode=True, na_gc_mode=gc_mode)
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(mod.gen.llvm_ir);
}

"""The body of function `name` in `text`."""
def body_of(text: str, name: str) -> str {
    found = re.search(r'define [^\n]*\.' + name + r'"?\(.*?\n}\n', text, re.S);
    assert found is not None , f"{name} not found in the IR";
    return found.group(0);
}

"""Does `name` link an unwind record (it then has a cleanup function)?"""
def links_record(text: str, name: str) -> bool {
    return re.search(r'define [^\n]*\.' + name + r'\.__unwind"', text) is not None;
}

test "frames that hold a local only across their own raises link no record" {
    for gc_mode in ["rc", "cycles"] {
        text = fixture_ir(gc_mode);
        for name in ["lookup", "make"] {
            assert not links_record(text, name) , f"{gc_mode} {name} links a record";
            assert "__jac_exception_context" not in body_of(text, name) , f"{gc_mode} {name} fetches the context";
        }
        assert links_record(text, "keep") , f"{gc_mode} keep lost its record";
    }
}

test "frames and handlers fetch the context through the inlined fast path" {
    text = fixture_ir("rc");
    assert '@"__jac_exception_context.inl"()' in body_of(text, "keep");
    found = re.search(r'define [^\n]*@"__jac_exception_context\.inl"\(\)[^\n]*', text);
    assert found is not None , "no inlined lookup";
    assert "alwaysinline" in found.group(0)
        or re.search(r'attributes #\d+ = \{[^}]*alwaysinline', text) is not None;
    guard = body_of(text, "guard");
    assert '@"__jac_region_tls_used"' in guard;
    assert "region.depth.read" in guard;
}

test "the program prints what the Python backend prints under rc and managed" {
    out = assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
    assert out.splitlines()[0] == "24080 280" , out;
}

test "raises from frames without a record leak nothing" {
    leak_fixture = os.path.join(NATIVE_FIXTURES, "unwind_leaf_leaks.jac");
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
        assert proc.stdout.splitlines()[0] == "24080280" , proc.stdout[:400];
        assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
        leaks = [
            line
            for line in proc.stdout.splitlines()
            if "<- LEAK" in line
        ];
        # (the global table itself is still alive at exit)
        assert len(leaks) == 1 and "type=list_ptr" in leaks[0] , f"{memory}: {leaks[:5]}";
    }
}
