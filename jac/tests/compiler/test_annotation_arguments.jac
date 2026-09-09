"""Annotation arguments preserve shape and reject mapping spreads."""
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

test "mapping spreads in generic annotations report a type diagnostic" {
    program = JacProgram();
    program.compile(
        file_path="annotation_spread.jac",
        use_str="def probe(value: dict[(str, **int)]) -> None {}",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    messages = "\n".join(error.pretty_print() for error in program.errors_had);
    assert "E1038" in messages , messages;
}

test "valid tuple and callable annotation arguments retain their types" {
    program = JacProgram();
    program.compile(
        file_path="annotation_arguments.jac",
        use_str="def probe(callback: Callable[[int, str], str], value: tuple[int, str]) -> str { return callback(value[0], value[1]); }",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}
