"""Owned module globals (#7870 item 5 surface): `glob x: own T` parses
through the same ownership-prefix path as locals and params, stamps the
symbol owned, and lifts the enforced-mode E1406 rejection of heap-typed
module globals -- the owned world's extent is the process. Unannotated
heap globals keep the fence."""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

glob FIXTURE = os.path.join(
         TESTS_DIR,
         "compiler",
         "passes",
         "main",
         "fixtures",
         "ownership",
         "own_glob_ok.jac"
     ),
     MODE_FLAGS = {
         "none": ["--enforce-nogc", "--gc", "none", "--assert-no-rc"],
         "rc": ["--gc", "rc"],
         "cycles": ["--gc", "cycles"]
     };

test "own globals are clean in the checker" {
    prog = compile_fixture("own_glob_ok.jac");
    expect_ownership_codes(prog, []);
}

test "own globals compile and run identically across gc modes including enforced" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"og_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "nacompile", FIXTURE]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            outs[mode] = ran.stdout;
        }
        assert outs["none"] == "3\nt0\n" , outs["none"];
        assert outs["rc"] == outs["none"] , outs["rc"];
        assert outs["cycles"] == outs["none"] , outs["cycles"];
    }
}
