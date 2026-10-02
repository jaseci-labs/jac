"""An override a flat imported base's own body skips is refused, not lost.

`test_native_xmod_virtual_dispatch.jac` (#8288) made a base's own
`self.hook()` reach an importer's override -- through the vtable the base
already carries. A ROOT class that nothing in its own module derives from,
names in an `isinstance`, or declares abstract carries none: `LayoutPass`
decides vtables per module and lays it out flat, so its methods bind
`self.trace()` straight to its own `trace`. An importer's subclass then has
its header dropped to match (`relax_vtable_header`), and when it inherits
such a method its override is never reached. The fixture's
`FlatSource.spot` returned -1 natively for a `TreeSource`, where the server
pathway answers 8: the base body ran and nothing said so.

The per-module decision cannot be made open-world without giving every
public class a header, so the divergence is refused where both layouts are
in hand -- at the override -- with E5113, pointing at the shape that does
dispatch: an abstract method reserves the base's vtable for implementations
in other modules.

As with E5089 the detection is narrow and the controls are the point:

  * `TreeSource.name` also overrides a flat base method, but no base body
    calls `self.name()`; nothing this unit can see diverges, so it is not
    reported (`test_inherited_slot_headers.jac` compiles that shape).
  * `TreeSource.label` overrides nothing.
  * `OpenSource` declares `trace` abstract; the importer's override is
    dispatched both through the base's own `spot` and through a variable
    typed as the base, and the binary must agree with the server pathway.
  * `Extended` adds a method to the flat base without overriding any.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { jac_command, TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FLAT_FIXTURE = "xmod_flat_override_main.jac",
     OPEN_FIXTURE = "xmod_open_override_main.jac",
     _RUN_MEMO: dict[(str, str)] = {};

"""Build a fixture natively: the compiler's exit code and everything it
printed, and the binary's path."""
def na_build(fixture: str) -> tuple[int, str, str] {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command(
            "build", "--native", os.path.join(FIXTURES, fixture), "-o", out_bin
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    return (comp.returncode, (comp.stdout or "") + (comp.stderr or ""), out_bin);
}

"""A fixture's output lines through one pathway, run at most once per process."""
def run_lines(fixture: str, native: bool) -> list[str] {
    key = f"{'na' if native else 'sv'}:{fixture}";
    if key not in _RUN_MEMO {
        if native {
            (code, log, out_bin) = na_build(fixture);
            assert code == 0 , f"nacompile failed: {log[-900:]}";
            proc = subprocess.run(
                [out_bin], capture_output=True, text=True, timeout=120
            );
            assert proc.returncode == 0 , f"binary exited {proc.returncode}: {proc.stderr[-400:]}";
            _RUN_MEMO[key] = proc.stdout;
        } else {
            proc = subprocess.run(
                jac_command("run", os.path.join(FIXTURES, fixture)),
                capture_output=True,
                text=True,
                timeout=900
            );
            assert proc.returncode == 0 , f"sv run failed: {proc.stderr[-800:]}";
            _RUN_MEMO[key] = proc.stdout;
        }
    }
    return [
        line.strip()
        for line in _RUN_MEMO[key].split("\n")
        if line.strip()
    ];
}

test "the server pathway runs the override through the flat base" {
    assert run_lines(FLAT_FIXTURE, False) == ["spot=8"] , (
        "`FlatSource.spot` dispatches `self.trace`, and TreeSource's trace "
        "adds 7: the answer is 8, and native must not quietly answer -1"
    );
}

test "overriding a flat imported base's method is refused with E5113" {
    (code, log, _) = na_build(FLAT_FIXTURE);
    assert code != 0 , f"the build must refuse the lost override; got: {log[-900:]}";
    assert "E5113" in log , f"the refusal must be E5113, got: {log[-900:]}";
    assert "'TreeSource.trace' overrides 'FlatSource.trace'" in log , (
        f"the refusal must name the override and the base body that would run: {log[-900:]}"
    );
    assert "xmod_flat_base.jac" in log , f"the refusal must name the base's module: {log[-900:]}";
    assert "'FlatSource.spot' calls" in log , (
        f"the refusal must name the inherited base method that skips the override: {log[-900:]}"
    );
    assert "TreeSource.label" not in log and "TreeSource.name" not in log , (
        f"overrides no base body dispatches to must not be reported: {log[-900:]}"
    );
}

test "an abstract base method dispatches to the importer's override" {
    na = run_lines(OPEN_FIXTURE, True);
    assert "spot=8" in na and "held=9" in na , (
        f"the override must run through the base's own body and through a "
        f"variable typed as the base; got {na}"
    );
    assert "flat=-1 extended" in na , (
        f"extending a flat base without overriding stays unreported and runs "
        f"the base body; got {na}"
    );
    assert run_lines(OPEN_FIXTURE, False) == na , "the binary and the server pathway must agree";
}
