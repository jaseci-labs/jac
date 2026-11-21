"""Type and compile-time value parameters retain distinct ordered slots."""
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

test "mixed generic arguments preserve compile-time values" {
    program = JacProgram();
    program.compile(
        file_path="mixed_type_parameters.jac",
        use_str="obj Box[T, comptime size: int] { has value: T; comptime width: int = size; }\n"
            + "comptime SMALL: int = Box[int, 3](value=1).width;\n"
            + "comptime LARGE: int = Box[str, 7](value='x').width;\n"
            + "with entry { comptime assert SMALL == 3; comptime assert LARGE == 7; }\n",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}

test "runtime values cannot fill compile-time type parameter slots" {
    program = JacProgram();
    program.compile(
        file_path="runtime_type_parameter.jac",
        use_str="obj Box[T, comptime size: int] { has value: T; }\n"
            + "def bad(size: int) -> None { box = Box[int, size](value=1); }\n",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    messages = "\n".join(error.pretty_print() for error in program.errors_had);
    assert "E0033" in messages , messages;
}

"""A comptime import binds a name for the compiler, so a type is not a runtime use.

`comptime import` is resolved while compiling and emits no runtime binding, and
an annotation or an `as` cast is read by the checker for the same reason: both
are gone before the program runs. Naming such an import in a type position is
therefore what it is for, not a compile-time value escaping into runtime code.
"""
test "a comptime-imported name used only as a type is not a runtime use" {
    program = JacProgram();
    program.compile(
        file_path="comptime_import_type_position.jac",
        use_str="comptime import from pathlib { Path }\n"
            + "def name_of(p: Path) -> str { return str(p); }\n"
            + "def widen(raw: any) -> str { return name_of(raw as Path); }\n",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    messages = "\n".join(error.pretty_print() for error in program.errors_had);
    assert "E0033" not in messages , (
        "a comptime import named in an annotation or an `as` cast is consumed "
        f"by the checker, not at runtime:\n{messages}"
    );
}
