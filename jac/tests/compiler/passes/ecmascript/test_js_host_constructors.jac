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
    js = compile_fixture_to_js("js_host_constructors.jac");
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

test "bare host constructor calls emit W6010 at jac check" {
    prog = compile_fixture("js_host_constructors.jac");
    warnings = warnings_with_code(prog, "W6010");
    warned_names = [str(w) for w in warnings];
    assert any("TextEncoder" in w for w in warned_names) , (
        "Expected W6010 for TextEncoder(), got: " + str(warned_names)
    );
    assert any("URL" in w for w in warned_names) , (
        "Expected W6010 for URL(...), got: " + str(warned_names)
    );
    assert any("WebSocket" in w for w in warned_names) , (
        "Expected W6010 for WebSocket(...), got: " + str(warned_names)
    );
    assert any("Promise" in w for w in warned_names) , (
        "Expected W6010 for Promise(...), got: " + str(warned_names)
    );
}

test "WebAssembly namespace is not treated as a constructor" {
    prog = JacProgram();
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write("def:pub f() -> any { return WebAssembly(); }\n");
        f.flush();
        ir = prog.compile(f.name, type_check=True);
    }
    warnings = warnings_with_code(prog, "W6010");
    assert len(warnings) == 0 , (
        "WebAssembly() must not warn W6010, got: " + str([str(w) for w in warnings])
    );
    assert ir.gen.js and "Reflect.construct(WebAssembly" not in ir.gen.js , (
        "WebAssembly() must not lower through Reflect.construct; got:\n"
        + (ir.gen.js or "<no js>")
    );
}

test "new(TextEncoder) does not emit W6010" {
    prog = compile_inline("def:pub f() -> any { return new(TextEncoder); }\n");
    warnings = warnings_with_code(prog, "W6010");
    assert len(warnings) == 0 , (
        "new(TextEncoder) must not warn W6010, got: " + str([str(w) for w in warnings])
    );
}

test "user-declared symbol shadowing a host name is not lowered" {
    prog = JacProgram();
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write(
            "def Date() -> any { return 1; }\n"
            "def:pub f() -> any { return Date(); }\n"
        );
        f.flush();
        ir = prog.compile(f.name, type_check=True);
    }
    warnings = warnings_with_code(prog, "W6010");
    assert len(warnings) == 0 , (
        "A user-defined Date() must not warn W6010, got: "
        + str([str(w) for w in warnings])
    );
    assert ir.gen.js and "Reflect.construct(Date" not in ir.gen.js , (
        "A user-defined Date() must stay a plain call; got:\n"
        + (ir.gen.js or "<no js>")
    );
}

test "callable builtins stay plain calls" {
    prog = JacProgram();
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write(
            "def:pub f() -> any { n = Number(\"42\"); s = String(n); b = BigInt(\"7\"); return s; }\n"
        );
        f.flush();
        ir = prog.compile(f.name, type_check=True);
    }
    warnings = warnings_with_code(prog, "W6010");
    assert len(warnings) == 0 , (
        "Number/String/BigInt are callable without new and must not warn W6010, got: "
        + str([str(w) for w in warnings])
    );
    assert not prog.errors_had , (
        "Number/String/BigInt inline program must compile cleanly, got: "
        + str([str(e) for e in prog.errors_had])
    );
    js = ir.gen.js or "";
    for fn in ["Number", "String", "BigInt"] {
        assert "Reflect.construct(" + fn not in js , (
            fn + "() is callable without new and must stay a plain call; got:\n" + js
        );
    }
}

test "host constructor call with kwargs lowers but reports E6010" {
    prog = JacProgram();
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write(
            "def:pub k1() -> any {\n"
            "    enc = TextEncoder();\n"
            "    url = URL(\"https://example.com\", params=\"a=b\");\n"
            "    ws = WebSocket(\"ws://example.com\");\n"
            "    promise = Promise(lambda (resolve: any, reject: any) {\n"
            "        resolve.call(None, \"done\");\n"
            "    });\n"
            "    return \"hi\";\n"
            "}\n"
        );
        f.flush();
        ir = prog.compile(f.name, type_check=True);
    }
    kw_errors = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E6010"
    ];
    assert len(kw_errors) == 1 , (
        "A kwarg'd host constructor call must report exactly one E6010 "
        "(host ctors are positional-only), got: "
        + str([str(e) for e in prog.errors_had])
    );
    js = ir.gen.js or "";
    assert "Reflect.construct(TextEncoder, [])" in js , (
        "TextEncoder() must lower; got:\n" + js
    );
    assert "Reflect.construct(URL," in js , (
        "URL(...) with kwargs must still lower through Reflect.construct so the "
        "emitted JS stays syntactically valid; got:\n"
        + js
    );
    assert "URL(" not in js.replace("Reflect.construct(URL, ", "") , (
        "No bare URL() call may remain; got:\n" + js
    );
}
