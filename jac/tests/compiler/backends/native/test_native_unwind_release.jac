"""A raise releases what the frames it crosses own; C argument temporaries too.

A raise reaches its handler with `longjmp`, skipping every frame in between
and the scope cleanup each would have run on a normal return, so every rc
object those frames held leaked once per raise (a JacPython argument parser
failing a conversion leaked about a dozen objects per call). A frame that
owns rc locals now links a node into the thread's unwind chain, and the raise
releases each crossed frame's locals before it jumps. A handler that binds no
name releases the caught exception when it finishes, and a name bound again
in a loop releases the exception it held before.

An owned `bytes` or `str` temporary passed straight to a C function whose
signature goes through the C ABI plan (a slice of a bytes field handed to
`memchr`) was never released after the call.

The fixtures agree with the Python backend, and a debug build's live-object
dump (or macOS `leaks`, for the byte buffers the dump does not track) must
hold nothing at exit.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { assert_native_identity, jac_command, native_build }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

"""Build `fixture` as a debug binary under `memory` and return the leaked lines."""
def debug_leaks(fixture: str, memory: str) -> tuple[str, list[str]] {
    with tempfile.TemporaryDirectory() as scratch {
        binary = os.path.join(scratch, "probe");
        comp = subprocess.run(
            jac_command(
                "build",
                "--native",
                str(FIXTURES / fixture),
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
        proc = subprocess.run([binary], capture_output=True, text=True, timeout=120);
        assert proc.returncode == 0 , proc.stderr[-800:];
    }
    assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
    leaks = [
        line
        for line in proc.stdout.splitlines()
        if "<- LEAK" in line
    ];
    return (proc.stdout.splitlines()[0], leaks);
}

test "raises through rc frames agree with the Python backend" {
    out = assert_native_identity(
        str(FIXTURES / "unwind_release.jac"), profiles=["rc", "managed"]
    );
    assert out.strip() == "515100" , out;
    out = assert_native_identity(
        str(FIXTURES / "unwind_handlers.jac"), profiles=["rc", "managed"]
    );
    assert out.strip() == "5750" , out;
}

test "a raise releases the locals of every frame it crosses" {
    for memory in ["rc", "managed"] {
        (first, leaks) = debug_leaks("unwind_release_leaks.jac", memory);
        assert first == "515100" , first;
        assert not leaks , f"{memory}: {len(leaks)} leaked, e.g. {leaks[:3]}";
    }
}

test "caught exceptions are released whether or not a handler binds them" {
    for memory in ["rc", "managed"] {
        (first, leaks) = debug_leaks("unwind_handlers_leaks.jac", memory);
        assert first == "5750" , first;
        assert not leaks , f"{memory}: {len(leaks)} leaked, e.g. {leaks[:3]}";
    }
}

test "owned bytes and str temporaries passed to C are released after the call" {
    if not shutil.which("leaks") {
        testskip("the macOS leaks tool is not available");
    }
    with tempfile.TemporaryDirectory() as scratch {
        for memory in ["rc", "managed"] {
            binary = os.path.join(scratch, f"c_args.{memory}");
            native_build(
                str(FIXTURES / "c_arg_temporaries.jac"), binary, memory=memory
            );
            lk = subprocess.run(
                ["leaks", "--atExit", "--", binary],
                capture_output=True,
                text=True,
                timeout=300
            );
            assert "600" in lk.stdout , lk.stdout[-2000:];
            assert "0 leaks for 0 total leaked bytes" in lk.stdout , (
                f"{memory}: {lk.stdout[-2000:]}"
            );
        }
    }
}
