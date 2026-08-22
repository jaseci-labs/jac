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
         TESTS_DIR, "compiler", "passes", "native", "fixtures", "nogc_abort_drops.jac"
     );

test "enforced raise runs frame drops exactly once, then aborts" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "abortdrops");
        res = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "nacompile",
                FIXTURE,
                "--enforce-nogc",
                "--gc",
                "none",
                "--assert-no-rc",
                "-o",
                out_bin
            ],
            capture_output=True,
            text=True
        );
        assert res.returncode == 0 , res.stderr;
        ran = subprocess.run([out_bin], capture_output=True, text=True);
        assert ran.returncode != 0 , "abort must terminate non-zero";
        out = ran.stdout;
        assert "before" in out , out;
        assert out.count("drop 1") == 1 , out;
        assert out.count("drop 2") == 1 , out;
        assert "never" not in out , out;
        _banner = out.find("unhandled exception");
        assert _banner >= 0 , out;
        assert out.find("drop 1") < _banner and out.find("drop 2") < _banner , out;
    }
}
