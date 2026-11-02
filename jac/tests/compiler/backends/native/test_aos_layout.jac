"""By-value AoS element buffers (#7870 item 3): a `list[own T]` of a
scalar-fielded archetype may lower to a contiguous by-value buffer under
enforced headerless codegen and to pointer elements under managed modes;
either way the output is byte-identical across gc modes and every element
is dropped exactly once. The macOS `leaks` gate pins the
teardown exact (the deferred Valgrind-matrix stand-in)."""

import os;
import shutil;
import subprocess;
import tempfile;
import from tests.support { jac_command, TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "aos_layout.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

test "AoS output is byte-identical across gc modes and leak-free" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        bins: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"aos_{mode}");
            res = subprocess.run(
                jac_command("build", "--native", FIXTURE)
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
        lines = outs["none"].split("\n");
        assert lines[0].isdigit() , outs["none"];
        assert sorted(lines[1:13]) == sorted([f"drop {i}" for i in range(12)]) , outs[
            "none"
        ];
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
