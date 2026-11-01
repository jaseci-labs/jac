"""Inferred move-in for container grow arguments (#7857 Phase E frontier).

A named binding appended into a container while dead-after (the
rc_last_use fact) moves in instead of copying, and the local's release
becomes a no-op. Bindings still live after the append keep copy-in
semantics, so a later write to one never reaches the container; output is
byte-identical across gc modes either way.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { jac_command, TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "move_in_infer.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

test "move-in output is byte-identical across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"mi_{mode}");
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
        }
        assert outs["none"] == "1\nwor1d\n1\nend\n" , outs["none"];
        assert outs["rc"] == outs["none"] , outs["rc"];
        assert outs["cycles"] == outs["none"] , outs["cycles"];
    }
}
