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
