"""`return tail f(args);` is a guaranteed tail call on the native backend.

The callee reuses the caller's frame (LLVM `musttail`), so recursion through
tail calls runs in constant stack: a CPython-style evaluator can dispatch
from one handler to the next through a function-pointer table for as long as
it runs. `tail` is contextual, so a variable named `tail` still reads as one.
The Python backend runs the same program as ordinary calls.

A call that cannot reuse the frame is `E5113` naming why, never a silent
ordinary call; `return tail` on anything but a call is `E0097`.
"""

import os;
import resource;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support {
    assert_native_identity,
    compile_native_ir,
    jac_command,
    native_build,
    source_spelled
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "tail calls agree with the Python backend under every memory profile" {
    out = assert_native_identity(str(FIXTURES / "tail_calls.jac"));
    assert out.splitlines() == ["True False False True", "1275", "11", "5"] , out;
}

test "every tail call lowers to musttail" {
    ir = compile_native_ir("tail_calls_deep.jac");
    text = source_spelled(str(ir.gen.llvm_ir));
    assert text.count("musttail call") >= 4 , text[:2000];
}

test "ten million tail calls run in a one-megabyte stack under every profile" {
    # An unoptimized build: the optimizer turns some plain calls in tail
    # position into jumps on its own, so only `musttail` is left to keep the
    # stack flat here.
    def small_stack {
        (_soft, hard) = resource.getrlimit(resource.RLIMIT_STACK);
        resource.setrlimit(resource.RLIMIT_STACK, (1024 * 1024, hard));
    }
    with tempfile.TemporaryDirectory() as scratch {
        for memory in ["nogc", "rc", "managed"] {
            binary = os.path.join(scratch, f"tail_deep.{memory}");
            native_build(
                str(FIXTURES / "tail_calls_deep.jac"),
                binary,
                memory=memory,
                extra=["--debug"]
            );
            proc = subprocess.run(
                [binary],
                capture_output=True,
                text=True,
                timeout=120,
                preexec_fn=small_stack
            );
            assert proc.returncode == 0 , f"{memory}: exit {proc.returncode} {proc.stderr[-400:]}";
            assert proc.stdout.splitlines() == ["15000000", "30000000"] , (
                f"{memory}: {proc.stdout}"
            );
        }
    }
}

test "a tail call the frame cannot host is refused with the reason" {
    source = (FIXTURES / "tail_calls_refused.jac").read_text();
    for memory in ["nogc", "rc"] {
        with tempfile.TemporaryDirectory() as scratch {
            # A fresh directory: a warm placement cache remembers the demoted
            # functions and would skip the lowering that states each reason.
            staged = os.path.join(scratch, "tail_calls_refused.jac");
            Path(staged).write_text(source);
            comp = subprocess.run(
                jac_command(
                    "build",
                    "--native",
                    staged,
                    "--memory",
                    memory,
                    "-o",
                    os.path.join(scratch, "refused")
                ),
                capture_output=True,
                text=True,
                timeout=900
            );
        }
        text = comp.stdout + comp.stderr;
        assert comp.returncode != 0 , text[-1500:];
        for reason in [
            "the callee takes 2 parameters, the caller 1",
            "the callee returns i1, the caller i64",
            "an owned local must be released after the call",
            "a `finally` or `with` block must run after the call"
        ] {
            assert reason in text , f"{memory}: {reason}\n{text[-3000:]}";
        }
    }
}

test "return tail needs a call" {
    prog = JacProgram();
    prog.compile(
        file_path=str(FIXTURES / "tail_calls_syntax.jac"),
        options=CompileOptions(no_cgen=True)
    );
    codes = [
        e.code.code
        for e in prog.errors_had
        if e.code is not None
    ];
    assert "E0097" in codes , codes;
}
