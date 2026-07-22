"""Tests for bare JS host constructor calls in client code (issue #7651)."""

import os;
import tempfile;
import from tempfile { NamedTemporaryFile }
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     ),
     _test_tmp_dir: str = tempfile.mkdtemp(prefix="jac_test_js_host_ctor_");

def compile_fixture(fixture_name: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, fixture_name), type_check=True);
    return prog;
}

def compile_inline(code: str, type_check: bool = True) -> JacProgram {
    prog = JacProgram();
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write(code);
        f.flush();
        prog.compile(f.name, type_check=type_check);
    }
    return prog;
}

def compile_fixture_to_js(fixture_name: str) -> str {
    prog = JacProgram();
    ir = prog.compile(os.path.join(FIXTURES, fixture_name), type_check=True);
    assert ir.gen.js and ir.gen.js.strip() , (
        "Production JS codegen produced no output for " + fixture_name
    );
    return ir.gen.js;
}

def warnings_with_code(prog: JacProgram, code: str) -> list {
    return [
        w
        for w in prog.warnings_had
        if w.code is not None and w.code.code == code
    ];
}

test "bare host constructor calls lower to Reflect.construct in JS output" {
    js = compile_fixture_to_js("js_host_constructors.cl.jac");
    assert "Reflect.construct(TextEncoder, [])" in js , (
        "TextEncoder() must lower to Reflect.construct(TextEncoder, []); got:\n" + js
    );
    assert 'Reflect.construct(URL, ["https://example.com"])' in js , (
        "URL(...) must lower to Reflect.construct(URL, [url]); got:\n" + js
    );
    assert 'Reflect.construct(WebSocket, ["ws://example.com"])' in js , (
        "WebSocket(...) must lower to Reflect.construct(WebSocket, [url]); got:\n" + js
    );
    assert "Reflect.construct(Promise, [" in js , (
        "Promise(...) must lower to Reflect.construct(Promise, [...]); got:\n" + js
    );
    assert "TextEncoder()" not in js , (
        "Bare TextEncoder() must not appear in emitted JS; got:\n" + js
    );
}

test "bare host constructor calls emit W6005 at jac check" {
    prog = compile_fixture("js_host_constructors.cl.jac");
    warnings = warnings_with_code(prog, "W6005");
    warned_names = [str(w) for w in warnings];
    assert any("TextEncoder" in w for w in warned_names) , (
        "Expected W6005 for TextEncoder(), got: " + str(warned_names)
    );
    assert any("URL" in w for w in warned_names) , (
        "Expected W6005 for URL(...), got: " + str(warned_names)
    );
    assert any("WebSocket" in w for w in warned_names) , (
        "Expected W6005 for WebSocket(...), got: " + str(warned_names)
    );
    assert any("Promise" in w for w in warned_names) , (
        "Expected W6005 for Promise(...), got: " + str(warned_names)
    );
}

test "new(TextEncoder) does not emit W6005" {
    prog = compile_inline("cl def f() -> any { return new(TextEncoder); }\n");
    warnings = warnings_with_code(prog, "W6005");
    assert len(warnings) == 0 , (
        "new(TextEncoder) must not warn W6005, got: " + str([str(w) for w in warnings])
    );
}
