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

`Plain.note` is the same method with `self` left implicit. Its list never
held the receiver, so its slots were already correct -- which is why every
existing `**kwargs` fixture passed and this fault stayed invisible. Both
spellings are exercised here so the fix cannot be read as "variadics work
now" when what changed is who counts the receiver.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { TESTS_DIR, compile_mir, jac_command }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "kwargs_explicit_self.jac",
     EXPECTED: tuple[str, ...] = ("3205", "7", "1121", "2104", "1105");


def sv_lines(fixture: str) -> list[str] {
    proc = subprocess.run(
        jac_command("run", os.path.join(FIXTURES, fixture)),
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


def na_lines(fixture: str) -> list[str] {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command(
            "build", "--native", os.path.join(FIXTURES, fixture), "-o", out_bin
        ),
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


test "an explicit-self variadic callee lowers with no refusal" {
    demoted = compile_mir(FIXTURE).demoted();
    assert not any("variadic" in reason for reason in demoted.values()) , (
        f"the receiver is still being counted twice: {demoted}"
    );
}


test "every caller of the explicit-self method reaches native code" {
    fx = compile_mir(FIXTURE);
    for name in (
        "spelled_literal",
        "spelled_defaulted",
        "spelled_scaled",
        "spelled_forwarded"
    ) {
        assert not fx.is_demoted(name) , (
            f"'{name}' demoted ({fx.demoted()}); a call into the explicit-self "
            f"variadic still binds a slot past the end of the callee"
        );
    }
    assert not fx.is_demoted("plain_literal") , (
        "the implicit-self spelling regressed, so the receiver is now being "
        f"subtracted from a list that never held it: {fx.demoted()}"
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
