"""Annotation arguments preserve shape and reject mapping spreads."""
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import ctypes;
import from tests.support { get_func, native_force_opts }

test "a field does not shadow its own annotated type in native construction" {
    program = JacProgram();
    module = program.compile(
        file_path="field_annotation.jac",
        use_str="""
obj pattern { has value: int = 7; }
obj MatchAs(pattern) { has pattern: pattern | None; }
def:pub read_child() -> int {
    child = pattern(value=42);
    parent = MatchAs(pattern=child);
    if parent.pattern is not None { return parent.pattern.value; }
    return -1;
}
""",
        options=native_force_opts()
    );
    assert not program.errors_had;
    assert module.gen.native_engine is not None;
    assert get_func(module.gen.native_engine, "read_child", ctypes.c_int64)() == 42;
}

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

test "a parenthesized tuple annotation unions with None on either side" {
    program = JacProgram();
    program.compile(
        file_path="paren_tuple_union.jac",
        use_str="""
def first(text: str) -> (str, int) | None {
    if not text { return None; }
    return (text[0], 0);
}
def last(text: str) -> None | (str, int) {
    if not text { return None; }
    return (text[-1], len(text) - 1);
}
def head(text: str) -> str {
    pair = first(text);
    if pair is None { return ""; }
    (ch, _) = pair;
    return ch;
}
""",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}

test "a parenthesized tuple in a union annotation still checks its elements" {
    program = JacProgram();
    program.compile(
        file_path="paren_tuple_union_mismatch.jac",
        use_str="def probe() -> (str, int) | None { return (1, 2); }",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    messages = "\n".join(error.pretty_print() for error in program.errors_had);
    assert "E1002" in messages , messages;
}
