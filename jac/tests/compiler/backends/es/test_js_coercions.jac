"""JavaScript primitive conversions retain callable rather than constructor semantics."""

import from jaclang.compiler.backends.es { EsastGenPass }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

test "JavaScript primitive conversions do not construct wrapper objects (#9096)" {
    program = JacProgram();
    module = program.compile(
        "js_coercions.jac",
        use_str="""
def boolean_value(value: any) -> bool { return Boolean(value) as bool; }
def number_value(value: any) -> any { return Number(value); }
def string_value(value: any) -> any { return String(value); }
""",
        options=CompileOptions(force_codespace="client", no_cgen=True)
    );
    EsastGenPass(ir_in=module, prog=program);
    assert not program.errors_had , "\n".join(
        str(error) for error in program.errors_had
    );
    for name in ["Boolean", "Number", "String"] {
        assert "new " + name + "(" not in module.gen.js , module.gen.js;
        assert "return " + name + "(value);" in module.gen.js , module.gen.js;
    }
}
