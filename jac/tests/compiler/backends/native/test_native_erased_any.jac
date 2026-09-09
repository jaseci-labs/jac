"""Why `Any` will never be in the compile-time import vocabulary, and codeinfo's clearing.

This file used to pin a refusal and a three-item clearing list: `typing`'s
compile-time vocabulary admitted `TypeVar`, `cast`, `TypeAlias` and
`ClassVar` but not `Any`, so `import from typing { Any }` answered
`unresolved import 'typing'` and `compiler/frontend/codeinfo.jac` -- whose only typing
import that was -- fell out of native inference. Three seams in
`capability_check_pass` were that one fact, and the list said what admitting
`Any` would cost.

The question is closed now, and not by admitting the name. `Any` is not
importable from `typing` at all: E1122 refuses every shape that binds it,
because jac has its own `any` and will not carry an aliased twin. A name the
language rejects can never reach the pre-scan, so there is nothing for the
vocabulary to decide. The first test below pins that -- the vocabulary must
keep refusing `Any`, now for a reason that cannot change back.

`codeinfo` spells its four annotations `any` and imports nothing from
`typing`, so the import-shaped blocker is gone. The hold that replaced the
accident is lane-scoped now: B4 (#8323) answered what it priced for the
compiler's own roots -- `test_codeinfo_baseline.jac` carried the closure and
its arriving seams until #8746 retired it with the rest of the seal's
coverage baselines -- so `PLACEMENT_HOLD_EXEMPT_ROOTS` exempts
`jac0core/` and `compiler/` from the hold, while user-facing inference keeps
it (admitting codeinfo there flipped byllm/scale module codespaces). The
third test below pins that contract: exactly codeinfo is held, its reason
names the exemption, and both compiler roots are exempt.

The clearing list, and where each item stands:

  1. `BaseTransform.prog: JacProgram`. The field had no native layout, so it
     was module-fatal for every closure member behind it. #8288's pass rim
     stamps `prog` on the instance at construction and the declaration is
     gone -- not widened to `any`, which would have been wrong twice over
     (only eleven passes shadowed it, so the rest would have silently lost
     every `self.prog.*` check). `compiler/passes/transform.jac` is a member
     of codeinfo's closure now, which is the measurement that says so.

  2 and 3. `codeinfo`'s `CLIENT_RUNTIME_SOURCE_PATHS` glob, which was a bare
     `tuple` whose element type did not lower, and would not lower annotated
     either: its rows were ragged -- two, three and six strings -- so a
     nested tuple annotation became one heterogeneous literal struct and
     storing it into a `%List.ptr` was a type mismatch. The shape had to
     change, and it did: a flat `list[str]` of "/"-joined relative paths,
     rejoined with `os.sep` at its one use site.

So the list is spent as a list: nothing on it blocks anything any more. The
single named hold that replaced it is spent too, and its prediction held
exactly: with the entry empty, four of `capability_check_pass`'s five seams
cleared -- three because it reads `codeinfo`'s tables in-unit, and
`ClientCapabilityCheckPass.transform` because the module-facts helpers (then
`module_codegen_pass`, now `frontend/module_facts`) joined alongside. That measurement lived in `test_pass_seal_wave6_baseline.jac`,
deleted with the native seal (#8735).

The last test keeps the half of the old reasoning that outlived the rest.
`ModuleFacts.is_erased_type_decl` reads the *marker* set
(`NATIVE_ERASED_TYPE_MARKERS`, `TypeAlias`) to decide which globs are
compile-time declarations the backend skips. An `any`-annotated glob is not
one: it is an ordinary global whose value has to reach the binary, and
classifying it as a declaration would drop it silently. That is the trap
`ClassVar` was lifted out of in #8278, and it holds for the lowercase
keyword exactly as it would have for the name.
"""

import os;
import from jaclang.compiler.frontend.codeinfo { native_erased_import_names }
import from jaclang.compiler.frontend.parser { parse as rd_parse }
import from jaclang.compiler.placement.placement { scan_native_blockers }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.frontend.unitree { Assignment, GlobalVars }
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE: str = "erased_any_annotation.jac";


"""Parse a fixture and return its module."""
def _parse(fixture: str) -> any {
    path = os.path.join(FIXTURES, fixture);
    with open(path, encoding='utf-8') as fh {
        src = fh.read();
    }
    (mod, had_err) = rd_parse(src, path, prog=JacProgram());
    assert not had_err , f"{fixture} did not parse";
    return mod;
}


test "the typing vocabulary refuses Any, and no module can ask it to" {
    assert not native_erased_import_names("typing", ["Any"]) , (
        "'Any' is in the compile-time import vocabulary. It must not be: "
        "E1122 refuses every import that binds the name, so admitting it "
        "here would describe a module the language cannot accept"
    );
    assert native_erased_import_names("typing", ["ClassVar", "cast"]) , (
        "the names that were already admitted must stay admitted"
    );
}


test "a module annotated with the any keyword needs no import to infer native" {
    (reason, _deps) = scan_native_blockers(_parse(FIXTURE), FIXTURES, allow_pub=True);
    assert reason == "" , (
        f"the pre-scan refused an any-annotated module with {reason!r}. The "
        "lowercase keyword is a builtin: it binds no import, so there is "
        "nothing here for the scan to resolve"
    );
}


test "the inference hold is lane-scoped: codeinfo held for users, compiler roots exempt" {
    import from jaclang.compiler.placement.placement {
        PLACEMENT_HOLD_EXEMPT_ROOTS,
        PLACEMENT_INFERENCE_HELD
    }
    assert set(PLACEMENT_INFERENCE_HELD) == {"compiler/frontend/codeinfo.jac"} , (
        "the inference hold table changed: "
        f"{sorted(PLACEMENT_INFERENCE_HELD)!r}. A hold is a deliberate debt "
        "with a named reason and a coverage measurement that prices it -- "
        "codeinfo's is carried here for user-facing inference only (B4, "
        "#8323, lane-scoped); a new entry needs the same treatment, and "
        "dropping this one re-opens the jaclang-internal import universe to "
        "default-native flips in user programs"
    );
    why = PLACEMENT_INFERENCE_HELD["compiler/frontend/codeinfo.jac"];
    assert "PLACEMENT_HOLD_EXEMPT_ROOTS" in why , (
        f"codeinfo's hold reason must name the exemption that answers it: {why!r}"
    );
    for marker in ("/jaclang/jac0core/", "/jaclang/compiler/") {
        assert marker in PLACEMENT_HOLD_EXEMPT_ROOTS , (
            f"{marker} is no longer exempt from the hold: "
            f"{PLACEMENT_HOLD_EXEMPT_ROOTS!r}. The compiler's own roots are "
            "what B4 unheld -- without the exemption the pass spine leaves "
            "every sealed closure again"
        );
    }
}


test "an any-annotated glob is not a compile-time declaration" {
    mod = _parse(FIXTURE);
    found = False;
    for stmt in mod.body {
        if not isinstance(stmt, GlobalVars) {
            continue;
        }
        for assign in stmt.assignments {
            if not isinstance(assign, Assignment) {
                continue;
            }
            found = True;
            assert not ModuleFacts.is_erased_type_decl(assign) , (
                "the any-annotated glob was classified as a compile-time "
                "declaration, so its value would never be emitted"
            );
        }
    }
    assert found , "the fixture no longer declares a glob to check";
}
