"""Sub-arena partition + reabsorb (#7857 Phase D).

`r.partition()` yields an owned child handle; a child's death reabsorbs
its chunks and dtor log into the parent (drops fire once, at the
parent's death, child entries first), and a parent dying before its
children defers teardown to the last reabsorb (zombie parent). Output is
byte-identical across gc modes.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures", "region_partition.jac"
     ),
     SUGAR_FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures", "region_partition_n.jac"
     ),
     SHARE_FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures", "region_page_share.jac"
     ),
     MODE_FLAGS = {
         "none": ["--gc", "none"],
         "rc": ["--gc", "rc"],
         "cycles": ["--gc", "cycles"]
     };

test "children draw pages from the parent behind the reabsorb contract" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=SHARE_FIXTURE,
        options=CompileOptions(aot_mode=True, type_check=True, na_gc_mode="rc")
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    text = str(ir.gen.llvm_ir);
    assert "raw.draw.lock" in text , "no parent draw path in __jac_region_raw";
    assert "raw.run" in text , "no run carving in __jac_region_raw";
    assert "merge.run" in text , "no run splice in __jac_region_drop";
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"share_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "nacompile", SHARE_FIXTURE]
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
        assert outs["rc"].startswith("pgshare:") , outs["rc"];
        assert outs["rc"].endswith("end\n") , outs["rc"];
        assert outs["none"] == outs["rc"] , outs["none"];
        assert outs["cycles"] == outs["rc"] , outs["cycles"];
    }
}

test "partition(n) sugar reabsorbs like the per-child form across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"partn_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "nacompile", SUGAR_FIXTURE]
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
        lines = outs["rc"].split("\n");
        assert lines[:3] == ["0", "1", "2"] , outs["rc"];
        assert sorted(lines[3:6]) == ["drop 0", "drop 1", "drop 2"] , outs["rc"];
        assert lines[6:] == ["end", ""] , outs["rc"];
        assert outs["none"] == outs["rc"] , outs["none"];
        assert outs["cycles"] == outs["rc"] , outs["cycles"];
    }
}

test "partition reabsorb and zombie teardown across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"part_{mode}");
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
        lines = outs["rc"].split("\n");
        _mid = lines.index("mid");
        _head = lines[:_mid];
        assert _head[:3] == ["0", "1", "2"] , outs["rc"];
        assert sorted(_head[3:]) == ["drop 0", "drop 1", "drop 2"] , outs["rc"];
        _tail = lines[_mid + 1:];
        assert _tail[:3] == ["8", "9", "before-c-drop"] , outs["rc"];
        assert _tail[3:5] == ["drop 9", "drop 8"] , outs["rc"];
        assert _tail[5:] == ["end", ""] , outs["rc"];
        assert outs["none"] == outs["rc"] , outs["none"];
        assert outs["cycles"] == outs["rc"] , outs["cycles"];
    }
}
