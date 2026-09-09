"""A variadic callee that spells `self` out binds its slots correctly (#8288).

Jac lets a method name its receiver in the signature, and
`TypeCheckPass.emit` does -- explicit `self`, four declared parameters, a
`**kwargs` sink. That is the only shape the argument binder counted the
receiver twice for. The call already supplies the receiver as argument zero
and offsets every parameter past it, and the list the binder walks still held
the `self` naming that same argument, so each declared parameter was matched
against the slot belonging to the one before it and the sink was looked for
one argument past the end of the callee. Finding nothing there, the call
refused under E5092 as a `variadic parameter '**'`.

The pre-flight check that decides whether the shape is lowerable at all
already subtracted the receiver, which is why the refusal came from the
binding path rather than the guard: the two disagreed about the same
signature, and only the guard was right.

`Plain.note` is the same method with `self` left implicit. Its list never
held the receiver, so its slots were already correct -- which is why every
existing `**kwargs` fixture passed and this fault stayed invisible. Both
spellings are exercised here so the fix cannot be read as "variadics work
now" when what changed is who counts the receiver.

The checker paid for this five times: `variadic parameter '**'` was its
second-largest cause, and clearing it took the file from 46 seams across 9
causes to 42 across 8. One of the five did not clear but moved -- it demotes
on the undeclared `self.evaluator` field instead, which the handshake still
owns.
"""

import contextlib;
import io;
import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "kwargs_explicit_self.jac",
     EXPECTED: tuple = ("3205", "7", "1121", "2104", "1105");

def compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, fixture), options=native_force_opts()
    );
    return (prog, ir, );
}


"""The seam report a build would show on stderr for a fixture."""
def seam_report(fixture: str) -> str {
    buf = io.StringIO();
    prog = JacProgram();
    with contextlib.redirect_stderr(buf) {
        prog.compile(
            file_path=os.path.join(FIXTURES, fixture), options=native_force_opts()
        );
    }
    return buf.getvalue();
}


def sv_lines(fixture: str) -> list {
    proc = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", os.path.join(FIXTURES, fixture)],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , f"server run failed: {proc.stderr[-800:]}";
    return [
        _l
        for _l in proc.stdout.split("\n")
        if _l.strip()
    ];
}


def na_lines(fixture: str) -> list {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "build",
            "--native",
            os.path.join(FIXTURES, fixture),
            "-o",
            out_bin
        ],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-900:]}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary exited {proc.returncode}: {proc.stderr[-400:]}";
    return [
        _l
        for _l in proc.stdout.split("\n")
        if _l.strip()
    ];
}


test "an explicit-self variadic callee lowers with no seam" {
    (prog, ir) = compile_native(FIXTURE);
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the fixture";
    seams = seam_report(FIXTURE);
    assert "variadic parameter" not in seams , (
        f"the receiver is still being counted twice:\n{seams}"
    );
}


test "every caller of the explicit-self method reaches native code" {
    (_prog, ir) = compile_native(FIXTURE);
    fns = ir.gen.native_layout.functions;
    for name in (
        "spelled_literal",
        "spelled_defaulted",
        "spelled_scaled",
        "spelled_forwarded"
    ) {
        assert name in fns , (
            f"'{name}' demoted; a call into the explicit-self variadic still "
            f"binds a slot past the end of the callee"
        );
    }
    assert "plain_literal" in fns , (
        "the implicit-self spelling regressed, so the receiver is now being "
        "subtracted from a list that never held it"
    );
}


test "bound slots answer as the server lane does" {
    sv = sv_lines(FIXTURE);
    assert sv == list(EXPECTED) , f"server lane printed {sv}";
    na = na_lines(FIXTURE);
    assert na == sv , (
        f"native {na} != server {sv}; a shifted slot binds the wrong argument "
        f"rather than refusing, so the answers diverge silently"
    );
}


test "str over a boxed kwargs value renders the value, not its tag" {
    fixture = "kwargs_any_str.jac";
    sv = sv_lines(fixture);
    na = na_lines(fixture);
    assert sv == na , (
        f"str(v) over dict[str, any] diverged between tiers: staged {sv} vs "
        f"native {na}. The native lowering once snprintf'd the raw JacVal "
        "box and printed the tag ('2' for a str), which shipped diagnostic "
        "messages with unfilled-looking values from sealed passes."
    );
    assert sv == ["keyword=break;", "keyword=break;n=3;"] , (
        f"the fixture's expected output drifted: {sv}"
    );
}
