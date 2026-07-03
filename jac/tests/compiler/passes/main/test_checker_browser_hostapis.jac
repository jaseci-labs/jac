"""Type checker tests for the WHATWG browser host-API surface (issue #7114).

QA of the this_is_jac showcase found `jac check` failing on functionally
correct cl code because the JS type universe did not model the host APIs
the code touches:
  - `fetch` returned `Promise[object]` (no `Response` model), so `.ok`,
    `.status`, `.json()`, `.text()`, `.body` all errored E1030
  - `await` did not unwrap `Promise[T]` (no `__await__` on the stub), so
    every awaited result stayed a Promise and cascaded E1055/E1001
  - `TextDecoder`/`TextEncoder` and `ReadableStream`(+reader) did not
    exist at all (E1053/E1031/E1032)
  - `navigator.clipboard` was bare `object`, so `.writeText()` errored
  - `_Document` lacked `pointerLockElement`/`exitPointerLock`

Scope rule pinned here (see #7114): model the HOST environment only --
JS method surfaces are never grafted onto Jac primitives; primitive-level
JS-isms in user code are the portability lint's job (W6002), not the
type environment's.
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
    assert mod is not None , f"fixture '{fixture_name}' failed to parse:\n" + "\n".join(
        str(e) for e in program.errors_had
    );
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
# 1. The full host-API surface, end to end: fetch/Response, the
#    ReadableStream reader loop, TextDecoder/TextEncoder, `await`
#    unwrapping Promise[T], navigator.clipboard, and the document pointer
#    lock members -- the frontend.impl.jac SSE loop, NativeSection
#    fetch+json, SourceViewer/CodeBlock clipboard, and raylib_shim
#    pointer-lock patterns.
# -------------------------------------------------------------------------
test "client browser host apis check cleanly and stay strict" {
    program = compile_and_check("checker_browser_hostapis.cl.jac");

    pretty = "\n".join([e.pretty_print() for e in program.errors_had]);
    # The fixture's ONLY error must be the deliberate `resp.nope()` E1030 --
    # everything else (fetch -> Response, the reader loop, text codecs,
    # await-unwrapping, clipboard, pointer lock) checks clean, and Response
    # is a genuine strict model, not a permissive Unknown/any escape.
    assert len(program.errors_had) == 1 , "the browser host-API surface must type-check with exactly the "
    "one deliberate error (resp.nope()), "
    f"got {len(program.errors_had)} diagnostic(s):\n{pretty}";
    only = program.errors_had[0];
    assert only.code is not None
    and only.code.code == "E1030"
    and "nope" in only.pretty_print() , "the single expected error is E1030 on resp.nope() (Response has "
    f"no attribute nope), got:\n{pretty}";
}

# -------------------------------------------------------------------------
# 2. Server context: the new host stubs must NOT leak in -- gating
#    regression, mirroring the js_globals server test.
# -------------------------------------------------------------------------
test "server context does not see browser host apis" {
    program = compile_and_check("checker_browser_hostapis_server.jac");

    codes = error_codes(program);
    assert len(program.errors_had) > 0 , "TextDecoder must not resolve in server context. "
    f"Expected a diagnostic but the fixture checked cleanly (codes {codes}).";
}
