"""An importer's override is reached through a base's own body.

`test_native_xmod_virtual_dispatch.jac` (#8288) made a base's own
`self.hook()` reach an importer's override -- through the vtable the base
already carries. A ROOT class that nothing in its own module derives from,
names in an `isinstance`, or declares abstract used to carry none:
`LayoutPass` decided vtables per module and laid it out flat, so its methods
bound `self.trace()` straight to its own `trace`, and an importer's override
was never reached. The fixture's `FlatSource.spot` returned -1 natively for
a `TreeSource`, where the server pathway answers 8.

A public class whose own body declares a method another module could
override now carries a vtable in its defining module (`open_dispatch` in the
layout pass), so these shapes dispatch and the binary must agree with the
server pathway. E5113 still refuses an override a base lowered flat would
skip; it is the backstop for a base that ends up without a vtable.

  * `TreeSource.name` also overrides a base method no base body calls.
  * `TreeSource.label` overrides nothing.
  * `OpenSource` declares `trace` abstract; the importer's override is
    dispatched both through the base's own `spot` and through a variable
    typed as the base.
  * `Extended` adds a method to the base without overriding any.
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
     SPLIT_FIXTURE = "xmod_flat_split_override_main.jac",
     QUALIFIED_FIXTURE = "xmod_flat_qualified_main.jac",
     MIXIN_FIXTURE = "xmod_flat_mixin_main.jac",
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

test "the server pathway runs the override through the base" {
    assert run_lines(FLAT_FIXTURE, False) == ["spot=8"] , (
        "`FlatSource.spot` dispatches `self.trace`, and TreeSource's trace "
        "adds 7: the answer is 8"
    );
}

test "a public base's own body reaches an importer's override natively" {
    assert run_lines(FLAT_FIXTURE, True) == ["spot=8"] , (
        "native must not quietly answer -1 by running the base's own trace"
    );
}

test "a base whose members live in impl blocks dispatches the override" {
    # The same pair with every member declared in an `impl`: the class body
    # is then an impl node, not a statement list.
    assert run_lines(SPLIT_FIXTURE, False) == ["spot=8"];
    assert run_lines(SPLIT_FIXTURE, True) == ["spot=8"];
}

test "a base named through its module dispatches the override" {
    # `obj QualTree(xmod_flat_base.FlatSource)`: the same base, written as a
    # qualified name instead of an imported one.
    assert run_lines(QUALIFIED_FIXTURE, True) == run_lines(QUALIFIED_FIXTURE, False);
}

test "dispatch follows the order methods are inherited in" {
    # `Both(Via, Other)`: `Other.spot` is declared closer to `Both` in the
    # source than `FlatSource.spot`, but `Via` comes first, so the `spot`
    # `Both` inherits is the base's, and it must reach `Both.trace`.
    assert run_lines(MIXIN_FIXTURE, False) == ["spot=8"];
    assert run_lines(MIXIN_FIXTURE, True) == ["spot=8"];
}

test "an abstract base method dispatches to the importer's override" {
    na = run_lines(OPEN_FIXTURE, True);
    assert "spot=8" in na and "held=9" in na , (
        f"the override must run through the base's own body and through a "
        f"variable typed as the base; got {na}"
    );
    assert "flat=-1 extended" in na , (
        f"extending a base without overriding runs the base body; got {na}"
    );
    assert "leaf=101 8" in na , (
        f"a base body an intermediate class replaces is not inherited below "
        f"it; got {na}"
    );
    assert run_lines(OPEN_FIXTURE, False) == na , "the binary and the server pathway must agree";
}
