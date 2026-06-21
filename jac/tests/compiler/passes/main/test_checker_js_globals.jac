"""Type checker tests for client JS globals and generic `new`.

Regression coverage for the littleX TweetCard.cl.jac:25 failure, where
`Date.now() - new(Date, created_at).getTime()` produced four cascading
errors:
  - E1032 (Date is Unknown, no attribute "now")
  - E1053 (Unknown not assignable to new's `cls: type`)
  - E1030 ("object" has no attribute "getTime" -- new returned object)
  - E1055 (no __sub__ overload for Unknown/object)

Two independent fixes, each pinned below:
  1. ECMAScript / browser globals (Date, Math, JSON, console, ...) resolve
     in client context, and stay invisible (a real error) in server context.
  2. `new(cls, ...)` is generic over `cls`, returning an instance of the
     constructed type instead of bare `object`.
"""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }

glob CHECKER_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "checker"
     );

"""Compile a checker fixture and run the type check pass."""
def compile_and_check(fixture_name: str) -> JacProgram {
    program = JacProgram();
    mod = program.compile(os.path.join(CHECKER_FIXTURES, fixture_name));
    TypeCheckPass(ir_in=mod, prog=program);
    return program;
}

"""Codes of all diagnostics recorded on a program."""
def error_codes(program: JacProgram) -> list[str] {
    return [
        e.code.code
        for e in program.errors_had
        if e.code is not None
    ];
}

# -------------------------------------------------------------------------
# 1. Client context: JS globals resolve and chain cleanly.
#    This is the exact TweetCard.cl.jac:25 pattern plus Math/JSON/console.
# -------------------------------------------------------------------------
test "client js globals resolve" {
    program = compile_and_check("checker_js_globals_client.cl.jac");

    pretty = "\n".join([e.pretty_print() for e in program.errors_had]);
    assert len(program.errors_had) == 0 , "Client JS globals (Date/Math/JSON/console/parseInt) and "
    f"generic new() must type-check cleanly, got {len(program.errors_had)} "
    f"diagnostic(s):\n{pretty}";
}

# -------------------------------------------------------------------------
# 2. Server context: JS globals must NOT leak in -- gating regression.
#    `Date` has no server runtime, so it must stay Unknown (E1032).
# -------------------------------------------------------------------------
test "server js globals stay unknown" {
    program = compile_and_check("checker_js_globals_server.jac");

    codes = error_codes(program);
    assert "E1032" in codes , "Client JS globals must not leak into server context. "
    f"Expected E1032 (Date is Unknown) but got codes {codes}.";
}

# -------------------------------------------------------------------------
# 3. Generic new(): returns the constructed type, not bare object.
#    `new(Widget).render()` must resolve; `new(Widget).nope()` must error.
# -------------------------------------------------------------------------
test "new returns constructed type" {
    program = compile_and_check("checker_new_generic.jac");

    pretty = "\n".join([e.pretty_print() for e in program.errors_had]);
    # render() exists on Widget -- must NOT error. If new() returned object,
    # render() would be flagged with E1030 too.
    assert "render" not in pretty , "new(Widget).render() must resolve -- new() must return Widget, "
    f"not object. Unexpected diagnostic mentions render:\n{pretty}";

    # nope() does not exist on Widget -- must still be flagged, proving the
    # return type is genuinely Widget (not a permissive Unknown/any).
    e1030 = [
        e
        for e in program.errors_had
        if e.code is not None and e.code.code == "E1030"
    ];
    assert any("nope" in e.pretty_print() for e in e1030) , "new(Widget).nope() must error E1030 (Widget has no attribute nope). "
    f"Got diagnostics:\n{pretty}";
}
