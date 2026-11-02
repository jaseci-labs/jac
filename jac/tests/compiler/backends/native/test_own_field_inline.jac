"""Inline flattening of own-typed fields under headerless codegen (#7857 Phase B).

An `own`-typed field of a concrete archetype is stored by value inside the
parent's allocation in enforced headerless modules: the parent's LLVM struct
embeds the field struct (no pointer slot), field construction lands in
place (no separate malloc), and the parent's drop tears the field down
without a separate free. Managed modes keep pointer fields. Whatever the
layout, program output (drop order included) stays byte-identical across all
three gc modes, which is what the test pins.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { TESTS_DIR, jac_command }

glob FIXDIR = os.path.join(
         TESTS_DIR, "compiler", "passes", "fixtures", "nogc_ownfield"
     ),
     FIXTURE = os.path.join(FIXDIR, "own_field_drop_count.jac"),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

test "flattened output stays byte-identical across all gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"ofi_{mode}");
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
        assert outs["none"] == "drop 0\nmid\n2\ndrop 2\nend\n" , outs["none"];
        assert outs["rc"] == outs["none"] , outs["rc"];
        assert outs["cycles"] == outs["none"] , outs["cycles"];
    }
}
