"""`print` must not hand a null pointer to printf, nor drop an argument.

A bare `None` lowered to a null `i8*` and went straight into the `%s`
slot, so `print(None)` segfaulted the binary. Separately, an argument
whose sub-expression could not lower was skipped with a bare `continue`,
so `print(b"Hi".upper())` compiled natively and printed nothing at all --
no output, no diagnostic, exit 0. Every other failure in `_emit_print`
emits E5092 and declines the lowering; that one did not.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { jac_command, NATIVE_FIXTURES }

glob NONE_FIXTURE = os.path.join(
         NATIVE_FIXTURES, "print_none_and_unlowerable.jac"
     ),
     DEMOTE_FIXTURE = os.path.join(NATIVE_FIXTURES, "print_unlowerable_arg.jac"),
     STREAM_FIXTURE: str = os.path.join(NATIVE_FIXTURES, "print_streams.jac");


def _build_and_run(fixture: str, name: str) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, name);
        built = subprocess.run(
            jac_command("build", "--native", fixture) + ["-o", out_bin],
            capture_output=True,
            text=True
        );
        assert built.returncode == 0 , f"{name}: build failed: {built.stderr}";
        ran = subprocess.run([out_bin], capture_output=True, text=True);
        assert ran.returncode == 0 , (
            f"{name}: exited {ran.returncode} (139 is the null-pointer "
            f"segfault this guards): {ran.stderr}"
        );
        return ran.stdout;
    }
}


test "a None argument prints None instead of segfaulting" {
    got = _build_and_run(NONE_FIXTURE, "print_none");
    assert got == "start\nNone\nNone\n1 None tail\nend\n" , got;
}


test "an argument that cannot lower declines the lowering" {
    # `bytes.upper` has no native emitter, so the module must demote and
    # produce CPython's answer rather than silently printing nothing.
    ran = subprocess.run(
        jac_command("run", DEMOTE_FIXTURE), capture_output=True, text=True
    );
    assert ran.returncode == 0 , ran.stderr;
    assert "start\nb'HI'\nend\n" in ran.stdout , ran.stdout;
}


test "file= picks the stream instead of being dropped" {
    # The argument loop used to skip a keyword it could not lower, so
    # `file=sys.stderr` was ignored and its text went to stdout.
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "print_streams");
        built = subprocess.run(
            jac_command("build", "--native", STREAM_FIXTURE) + ["-o", out_bin],
            capture_output=True,
            text=True
        );
        assert built.returncode == 0 , built.stderr;
        assert "demoting run_cases" not in built.stdout + built.stderr , (
            "file=sys.stderr must lower natively, not demote"
        );
        ran = subprocess.run([out_bin], capture_output=True, text=True);
        assert ran.returncode == 0 , ran.stderr;
        assert ran.stdout == "out one\nout two\n" , ran.stdout;
        assert ran.stderr == "err one\nerr two 42\n" , ran.stderr;
    }
}
