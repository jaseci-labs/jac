"""A native AOT build resolves a dotted walk-up import whose target then
imports a sibling relatively (`import from .leaf`). Pins the boundary-fact
rule that a dependency compiled under the native default codespace carries
native intent for its own imports, so sibling resolution runs even before the
module's codespace is decided."""

import from tests.support { jac_command }

import os;
import subprocess;
import tempfile;

glob FIXTURE: str = os.path.abspath(
         os.path.join(
             os.path.dirname(os.path.abspath(__file__)),
             "..",
             "..",
             "..",
             "..",
             "jaclang",
             "compiler",
             "tests",
             "fixtures",
             "prim_walkup_transitive.jac"
         )
     );

test "dotted walk-up import then a relative sibling import lowers natively" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "walkup");
        res = subprocess.run(
            jac_command("build", "--native", FIXTURE, "-o", out_bin),
            capture_output=True,
            text=True
        );
        assert res.returncode == 0 , res.stderr;
        assert "demoting" not in res.stderr , res.stderr;
        ran = subprocess.run([out_bin], capture_output=True, text=True);
        assert ran.returncode == 0 , ran.stderr;
        assert ran.stdout == "mid(leaf:7)\n" , ran.stdout;
    }
}

test "parent-relative imported objects retain their native signature types" {
    import from pathlib { Path }
    with tempfile.TemporaryDirectory() as tmp {
        workspace = Path(tmp);
        nested = workspace / "formats" / "q1";
        nested.mkdir(parents=True);
        (nested.parent / "records.jac").write_text(
            "obj Record { has value: int = 42; }\n"
        );
        # Include an absolute-import control: it previously compiled but
        # crashed because region-kernel TLS globals were internalized.
        for (imports, expression) in [
            ("import from ..records { Record }", "Record"),
            ("import from ...formats.records { Record }", "Record"),
            ("import from formats.records { Record }", "Record"),
            ("import from ..records { Record as Shared }", "Shared")
        ] {
            (nested / "records.jac").write_text(
                imports
                    + "\n"
                    + "def make() -> "
                    + expression
                    + " { return "
                    + expression
                    + "(); }\n"
            );
            main_file = workspace / "main.jac";
            main_file.write_text(
                "import from formats.q1.records { make }\n"
                    + "with entry { print(make().value); }\n"
            );
            out_bin = str(workspace / "relative-types");
            res = subprocess.run(
                jac_command("build", "--native", str(main_file), "-o", out_bin),
                capture_output=True,
                text=True,
                cwd=tmp
            );
            assert res.returncode == 0 , imports + "\n" + res.stdout + res.stderr;
            assert "demoting" not in res.stderr , res.stderr;
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , imports + "\n" + ran.stderr;
            assert ran.stdout == "42\n" , ran.stdout;
        }
    }
}
