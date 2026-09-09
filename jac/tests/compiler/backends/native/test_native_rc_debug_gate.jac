"""Coverage for the compile-time RC trace gate.

The RC printf trace (RC MALLOC / RC RETAIN / RC RELEASE / RC FREE) is
emitted only when the build is a debug build (`jac build --native --debug`,
or `[native] debug = true` in jac.toml): NaIRGenPass reads
`rc_debug_codegen` from its compile options, which follow `native_debug`
when unset. Gate ON must reproduce the runtime-toggleable trace; gate OFF
must compile the trace out entirely and reduce `__rc_debug_enable()` to a
one-line stderr notice.

Each variant compiles a copy of the fixture inside its own tempdir so the
per-source `.jac/cache` lands there too — the two compiles can never see
each other's cached artifacts.
"""

import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures"),
     GATE_OFF_NOTICE = (
         "jac: RC debug tracing not compiled in"
         + " (build with --debug or [native] debug = true)"
     );


"""Compile the trace fixture with/without the codegen gate, run the binary.

`rc_debug_codegen` controls whether the build is invoked with `--debug`.
The child binary runs with the inherited environment; the gate acts at
compile time only. Returns the binary's (stdout, stderr).
"""
def _compile_and_run(rc_debug_codegen: bool) -> tuple[str, str] {
    with tempfile.TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "rc_debug_trace.jac");
        shutil.copyfile(os.path.join(FIXTURES, "rc_debug_trace.jac"), src);
        out_bin = os.path.join(tmp, "rc_debug_trace");
        cmd = [
            sys.executable,
            "-m",
            "jaclang",
            "build",
            "--native",
            src,
            "-o",
            out_bin
        ];
        if rc_debug_codegen {
            cmd.append("--debug");
        }
        comp = subprocess.run(cmd, capture_output=True, text=True, timeout=900);
        assert comp.returncode == 0 , (
            f"jac build --native (gate={rc_debug_codegen}) failed: exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-800:] if comp.stderr else '(empty)'}"
        );
        assert os.path.exists(out_bin) , f"binary not produced at {out_bin}";
        proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=60);
        assert proc.returncode == 0 , (
            f"binary (gate={rc_debug_codegen}) exited non-zero: {proc.returncode}\n"
            f"stderr: {proc.stderr[-800:] if proc.stderr else '(empty)'}"
        );
        return (proc.stdout or "", proc.stderr or "");
    }
}


test "rc debug gate ON: trace is compiled in and runtime-toggleable" {
    (out, _err) = _compile_and_run(True);
    assert "--- debug ON ---" in out , (
        f"__rc_debug_enable() must announce the runtime toggle.\nstdout: {out[:400]}"
    );
    assert "RC MALLOC" in out , (
        f"gate-ON binary emitted no RC MALLOC lines.\nstdout: {out[:400]}"
    );
    assert "RC FREE" in out , (
        f"gate-ON binary emitted no RC FREE lines.\nstdout: {out[:400]}"
    );
    assert "490" in out , (
        f"fixture total missing from gate-ON stdout.\nstdout tail: {out[-200:]}"
    );
}

test "rc debug gate OFF: trace compiled out, enable prints stderr notice" {
    (out, err) = _compile_and_run(False);
    assert "RC MALLOC" not in out , (
        f"gate-OFF binary still traces RC MALLOC.\nstdout: {out[:400]}"
    );
    assert "RC RETAIN" not in out and "RC FREE" not in out , (
        f"gate-OFF binary still traces retain/free.\nstdout: {out[:400]}"
    );
    assert "--- debug ON ---" not in out , (
        f"gate-OFF __rc_debug_enable() still prints the toggle banner.\n"
        f"stdout: {out[:400]}"
    );
    assert "490" in out , (
        f"fixture total missing from gate-OFF stdout.\nstdout: {out[:400]}"
    );
    assert GATE_OFF_NOTICE in err , (
        f"gate-OFF __rc_debug_enable() must print the stderr notice.\n"
        f"stderr: {err[:400]}"
    );
    assert "RC MALLOC" not in err , (
        f"trace lines leaked to gate-OFF stderr.\nstderr: {err[:400]}"
    );
}
