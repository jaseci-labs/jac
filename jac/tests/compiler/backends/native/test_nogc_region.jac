"""Regions inside nogc-enforced modules (#7857 Phase D keystone).

An enforced module may build, use, and drop region graphs with rc-free
asserted: the arena core (bump alloc, dtor log, bulk free) needs no RC,
so region opens stop being E1406 and the whole build-traverse-discard
shape compiles headerless, byte-identical to the managed modes.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "nogc_region.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

test "region build-traverse-discard compiles rc-free and matches managed output" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"rg_{mode}");
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
        }
        for k in range(3) {
            assert outs["none"].count(f"drop {k}") == 1 , outs["none"];
        }
        assert "3\n" in outs["none"] and outs["none"].endswith("end\n") , outs["none"];
        assert outs["rc"] == outs["none"] , f"rc diverged:\n{outs['rc']}\nvs\n{outs[
            'none'
        ]}";
        assert outs["cycles"] == outs["none"] , f"cycles diverged:\n{outs['cycles']}";
    }
}
