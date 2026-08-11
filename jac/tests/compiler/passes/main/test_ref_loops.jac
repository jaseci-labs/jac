"""Reference-yielding loops over containers (#7857 Phase C).

`for x in &xs` iterates shared per-element borrows and `for m in &mut xs`
iterates exclusive ones -- lowered as index loops with no reified iterator
object, so the loop is the borrow's extent. Element mutation through the
`&mut` form must be visible after the loop, byte-identically under every
gc mode including enforced headerless builds.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR,
         "compiler",
         "passes",
         "main",
         "fixtures",
         "nogc_ownfield",
         "ref_loop.jac"
     ),
     MODE_FLAGS = {
         "none": ["--enforce-nogc", "--gc", "none", "--assert-no-rc"],
         "rc": ["--gc", "rc"],
         "cycles": ["--gc", "cycles"]
     };

test "ref-loop mutation is visible and mode-identical" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"rl_{mode}");
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
        assert outs["rc"] == "3\n4\nend\n" , outs["rc"];
        assert outs["none"] == outs["rc"] , f"none diverged:\n{outs['none']}";
        assert outs["cycles"] == outs["rc"] , f"cycles diverged:\n{outs['cycles']}";
    }
}

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "ref-loop reads and post-loop owner reuse are clean" {
    prog = compile_fixture("ref_loop_clean.jac");
    expect_ownership_codes(prog, []);
}

test "storing a ref-loop variable into a field is E1306" {
    prog = compile_fixture("ref_loop_owner_write.jac");
    expect_ownership_codes(prog, ["E1306"]);
}

test "growing the iterated container inside the loop is E1303" {
    prog = compile_fixture("ref_loop_grow_conflict.jac");
    expect_ownership_codes(prog, ["E1303"]);
}

test "growing the container after the loop is clean" {
    prog = compile_fixture("ref_loop_grow_after_ok.jac");
    expect_ownership_codes(prog, []);
}
