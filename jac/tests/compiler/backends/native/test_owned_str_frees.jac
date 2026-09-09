"""Owned-heap string drops (#7870 runtime completions): the enforced
build frees owned string locals at their extent -- reassign, loop
iteration, scope exit -- while moves, returns, literals, and views
never double-free. Behavior byte-identical across gc modes; the macOS
leaks gate pins teardown (the deferred Valgrind-matrix stand-in)."""

import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "owned_str_frees.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

test "owned-str drops are byte-identical across modes and leak-free" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        bins: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"osf_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "build", "--native", FIXTURE]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            outs[mode] = ran.stdout;
            bins[mode] = out_bin;
        }
        assert outs["none"].strip().isdigit() , outs["none"];
        assert outs["rc"] == outs["none"] , f"{outs['rc']} vs {outs['none']}";
        assert outs["cycles"] == outs["none"] , outs["cycles"];
        if shutil.which("leaks") {
            lk = subprocess.run(
                ["leaks", "--atExit", "--", bins["none"]],
                capture_output=True,
                text=True
            );
            assert "0 leaks for 0 total leaked bytes" in lk.stdout , lk.stdout[-2000:];
        }
    }
}
