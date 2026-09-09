"""Abort-with-drops in enforced modules (#7857 Phase F, phase one).

An unhandled raise in a nogc-enforced frame runs that frame's
statically-known drop obligations -- the same cleanup block scope-exit
uses -- and then aborts. Deterministic resource cleanup with zero
EH-table machinery; drops fire exactly once, before the abort banner.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "nogc_abort_drops.jac"
     ),
     HANDLED = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "nogc_raise_drops.jac"
     );

def _build(src: str, out_bin: str) -> subprocess.CompletedProcess {
    return subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "build",
            "--native",
            src,
            "--memory",
            "nogc",
            "-o",
            out_bin
        ],
        capture_output=True,
        text=True
    );
}

test "an entry block that does not handle a raising call is E1407" {
    with tempfile.TemporaryDirectory() as tmp {
        res = _build(FIXTURE, os.path.join(tmp, "abortdrops"));
        assert res.returncode != 0 , res.stdout;
        assert "E1407" in res.stderr + res.stdout , res.stderr + res.stdout;
    }
}

test "a handled raise runs frame drops exactly once before the handler" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "raisedrops");
        res = _build(HANDLED, out_bin);
        assert res.returncode == 0 , res.stderr;
        ran = subprocess.run([out_bin], capture_output=True, text=True);
        assert ran.returncode == 0 , ran.stderr;
        out = ran.stdout;
        assert "before" in out , out;
        assert out.count("drop 1") == 1 , out;
        assert out.count("drop 2") == 1 , out;
        assert "never" not in out , out;
        _handled = out.find("handled");
        assert _handled >= 0 , out;
        assert out.find("drop 1") < _handled and out.find("drop 2") < _handled , out;
    }
}
