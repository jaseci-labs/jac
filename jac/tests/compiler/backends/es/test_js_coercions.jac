"""JavaScript primitive conversions retain callable rather than constructor semantics."""

import from jaclang.compiler.backends.es { EsastGenPass }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import shutil;
import subprocess;

def compile_client(source: str) -> str {
    program = JacProgram();
    module = program.compile(
        "js_coercions.jac",
        use_str=source,
        options=CompileOptions(force_codespace="client", no_cgen=True)
    );
    run_pass(TypeCheckPass, module, program);
    EsastGenPass(ir_in=module, prog=program);
    assert not program.errors_had , "\n".join(
        str(error) for error in program.errors_had
    );
    return module.gen.js;
}

def run_client(source: str, assertions: str) {
    js = compile_client(source);
    if not shutil.which("node") {
        testskip("node not on PATH");
    }
    result = subprocess.run(
        [
            "node",
            "--input-type=module",
            "-e",
            'import assert from "node:assert/strict";\n' + js + "\n" + assertions
        ],
        capture_output=True,
        text=True,
        timeout=30
    );
    assert result.returncode == 0 , result.stderr + "\n" + js;
}

test "JavaScript primitive conversions do not construct wrapper objects (#9096)" {
    js = compile_client(
        """
def boolean_value(value: any) -> bool { return Boolean(value) as bool; }
def number_value(value: any) -> float { return Number(value); }
def string_value(value: any) -> str { return String(value); }
"""
    );
    for name in ["Boolean", "Number", "String"] {
        assert "new " + name + "(" not in js , js;
        assert "return " + name + "(value);" in js , js;
    }
}

test "coercions and aliases return primitives and preserve JavaScript truthiness" {
    run_client(
        """
def boolean_value(value: any) -> bool { return Boolean(value) as bool; }
def boolean_alias(value: any) -> bool { convert = Boolean; return convert(value); }
def number_value(value: any) -> float { convert = Number; return convert(value); }
def string_value(value: any) -> str { convert = String; return convert(value); }
def defaults -> list { return [Boolean(), Number(), String()]; }
def helpers -> list {
    numeric = Number;
    text = String;
    return [numeric.isInteger(2), numeric.isFinite(0), numeric.parseInt("12", 10),
            text.fromCharCode(65), text.fromCodePoint(66)];
}
""",
        """
for (const value of [false, 0, "", null, undefined, NaN]) {
    assert.equal(boolean_value(value), false);
    assert.equal(boolean_alias(value), false);
}
for (const value of [true, 1, "x", [], {}, Object.create({endpoint: "push"})]) {
    assert.equal(boolean_value(value), true);
    assert.equal(boolean_alias(value), true);
}
assert.equal(number_value(0), 0);
assert.equal(number_value("12"), 12);
assert.equal(string_value(""), "");
assert.equal(string_value(12), "12");
assert.deepEqual(defaults(), [false, 0, ""]);
assert.deepEqual(helpers(), [true, true, 12, "A", "B"]);
"""
    );
}

test "classes shadowing coercion names remain constructors" {
    run_client(
        """
obj Boolean { has value: int; }
obj Number { has value: int; }
obj String { has value: int; }
def construct -> list[int] {
    boolean_class = Boolean;
    return [boolean_class(1).value, Number(2).value, String(3).value];
}
""",
        'assert.deepEqual(construct(), [1, 2, 3]);'
    );
}
