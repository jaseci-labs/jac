"""Runtime type values retain their identity through inference and narrowing."""
import from jaclang.compiler.driver.program { JacProgram }

test "dynamic bitwise values are not runtime type unions" {
    program = JacProgram();
    program.compile(
        file_path="dynamic_bitwise.jac",
        use_str='''
def flags(values: list) -> int {
    value: int = 0;
    for item in values {
        value = (item[0] << 4) | item[1];
    }
    return value;
}
''',
        no_cgen=True
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}

test "union aliases are runtime UnionType values and valid class information" {
    program = JacProgram();
    program.compile(
        file_path="runtime_union.jac",
        use_str='''
import from types { UnionType as RuntimeUnion }
obj Left {}
obj Right {}
glob Both = Left | Right;
def accept(value: RuntimeUnion) -> RuntimeUnion { return value; }
def identity[T](value: T) -> T { return value; }
def matches(value: object) -> bool { return isinstance(value, Both); }
def preserve(value: Left | Right) -> Left | Right { return value; }
with entry {
    alias = Both;
    union_value = accept(identity(alias));
    value: Left | Right = Left();
    assert matches(preserve(value));
    assert isinstance(value, union_value);
}
''',
        no_cgen=True
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}

test "union instances remain distinct from runtime union type values" {
    program = JacProgram();
    program.compile(
        file_path="invalid_runtime_union.jac",
        use_str='''
import from types { UnionType as RuntimeUnion }
obj Left {}
obj Right {}
glob Both = Left | Right;
def accept(value: RuntimeUnion) {}
def invalid_classinfo(value: object, instance: Left | Right) -> bool {
    return isinstance(value, instance);
}
def invalid_return -> Left | Right { return Both; }
with entry { accept(Left()); }
''',
        no_cgen=True
    );
    codes = [
        error.code.code
        for error in program.errors_had
        if error.code
    ];
    assert codes.count("E1053") == 2 , codes;
    assert codes.count("E1002") == 1 , codes;
}

test "callable narrows object without accepting an unchecked object" {
    program = JacProgram();
    program.compile(
        file_path="callable_object.jac",
        use_str='''
def accept(callback: Callable) {}
def guarded(value: object) {
    if callable(value) { accept(value); }
}
def unguarded(value: object) { accept(value); }
''',
        no_cgen=True
    );
    assert len(program.errors_had) == 1 , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
    code = program.errors_had[0].code;
    assert code is not None and code.code == "E1053";
}

test "optional attribute probes on object preserve unknown runtime values" {
    program = JacProgram();
    program.compile(
        file_path="optional_object_attribute.jac",
        use_str='''
def optional(value: object) -> str {
    record = value?.record;
    return record.name if record else "missing";
}
def direct(value: object) -> str { return value.record.name; }
''',
        no_cgen=True
    );
    messages = [error.pretty_print() for error in program.errors_had];
    assert messages , "direct object member access must still be rejected";
    assert all(error.loc.first_line == 6 for error in program.errors_had) , "\n".join(
        messages
    );
}

test "union bounds and constraints describe generic instance values" {
    program = JacProgram();
    program.compile(
        file_path="union_generic_bounds.jac",
        use_str='''
obj Left {}
obj Right {}
glob Bounded = TypeVar("Bounded", bound=Left | Right),
     Constrained = TypeVar("Constrained", Left | Right, int);
def bounded(value: Bounded) -> Bounded { return value; }
def constrained(value: Constrained) -> Constrained { return value; }
with entry {
    first: Left = bounded(Left());
    second: Right = constrained(Right());
    number: int = constrained(1);
    bounded("invalid");
    constrained("invalid");
}
''',
        no_cgen=True
    );
    errors = program.errors_had;
    assert len(errors) == 2 , "\n".join(error.pretty_print() for error in errors);
    assert all(error.code and error.code.code == "E1053" for error in errors);
}
