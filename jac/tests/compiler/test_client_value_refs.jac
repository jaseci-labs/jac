"""Client-side value references to server-placed functions (#8072).

Calls to a `def:pub` endpoint bridge over RPC through a call-site rewrite, but
a reference in any other position -- callback argument, container element,
`return f`, re-export -- fell through to the ordinary identifier path. The
function was never emitted into the client bundle, so the module threw
`ReferenceError` at runtime and nothing warned on the path that emits.

The fix binds instead of rewriting: a server endpoint reachable from client
code gets a real client-side forwarder, so the name is an ordinary JS value
that works in every position. Where no forwarder is possible (no endpoint
access, so nothing to forward to) codegen fails loudly instead of shipping an
unbound identifier.
"""

import os;
import from tests.support { JAC_ROOT }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace"
     );

"""Diagnostic code strings carried by a list of alerts."""
def codes_of(alerts: list[any]) -> list[str] {
    return [
        a.code.code
        for a in alerts
        if a.code is not None
    ];
}

"""Compile a codespace fixture all the way through client codegen."""
def build_fixture(rel: str) -> tuple[JacProgram, uni.Module] {
    prog = JacProgram();
    mod = prog.compile(os.path.join(FIXTURE_DIR, rel));
    return (prog, mod);
}

"""Compile a codespace fixture for analysis only (the `jac check` path)."""
def check_fixture(rel: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(
        os.path.join(FIXTURE_DIR, rel),
        options=CompileOptions(no_cgen=True, type_check=True)
    );
    return prog;
}


test "endpoint used as a client value is bound, not left dangling" {
    (prog, mod) = build_fixture("infer_value_ref_endpoint.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    js = mod.gen.js or "";
    assert "async function run_current_file(" in js , (
        "a server endpoint reachable from client code needs a real client "
        f"binding, not a bare identifier; got:\n{js}"
    );
    assert '__jacCallFunction("run_current_file"' in js , (
        f"the client forwarder must bridge over RPC; got:\n{js}"
    );
    assert 'registerCommand("x.run", run_current_file)' in js , (
        f"the value reference itself must stay an ordinary reference; got:\n{js}"
    );
}


test "a bound endpoint value reference no longer warns W6007" {
    prog = check_fixture("infer_value_ref_endpoint.jac");
    assert "W6007" not in codes_of(prog.warnings_had) , (
        "the forwarder gives the endpoint client presence, so the "
        "value-flow warning has nothing left to report"
    );
}


test "calls to the same endpoint still bridge over RPC" {
    (prog, mod) = build_fixture("infer_value_ref_call.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    js = mod.gen.js or "";
    assert '__jacCallFunction("push_tag", {"tag": "x"})' in js , (
        f"the call-site rewrite still carries Jac's calling convention; got:\n{js}"
    );
}


test "an endpoint used both as a value and as a call binds once" {
    (prog, mod) = build_fixture("infer_value_ref_mixed.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    js = mod.gen.js or "";
    assert js.count("async function push_tag(") == 1 , (
        f"exactly one client forwarder per endpoint; got:\n{js}"
    );
}


test "a value-returning endpoint used as a value is diagnosed as async" {
    (prog, mod) = build_fixture("infer_value_ref_returns.jac");
    assert "W6009" in codes_of(prog.warnings_had) , (
        "the forwarder is async, so its result is a Promise where the server "
        "function's is a plain value; that has to be said, not papered over"
    );
}


test "a None-returning endpoint used as a value is not diagnosed" {
    (prog, mod) = build_fixture("infer_value_ref_endpoint.jac");
    assert "W6009" not in codes_of(prog.warnings_had) , (
        "a callback that returns nothing has no result to await"
    );
}


test "a server-pinned non-endpoint used as a client value fails codegen" {
    (prog, mod) = build_fixture(os.path.join("value_ref_pinned", "app.jac"));
    errs = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == 'E5086'
    ];
    assert len(errs) == 1 , (
        f"expected exactly one E5086, got {[str(e) for e in prog.errors_had]}"
    );
    assert 'log_it' in str(errs[0]) , "E5086 must name the unbound symbol";
}


test "the unbridgeable value reference still warns W6007 at check time" {
    prog = check_fixture(os.path.join("value_ref_pinned", "app.jac"));
    assert "W6007" in codes_of(prog.warnings_had) , (
        "a value reference with no possible client binding is exactly what "
        f"W6007 describes; got {codes_of(prog.warnings_had)}"
    );
}
