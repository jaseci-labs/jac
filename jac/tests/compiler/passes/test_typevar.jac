"""TypeVar validation tests for the type checker."""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob CHECKER_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "checker"
     ),
     TYPEVAR_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "checker", "typevar"
     );

test "false variance flags remain invariant and adjacent name literals concatenate" {
    program = JacProgram();
    program.compile(
        file_path="typevar_literal_contract.jac",
        use_str="with entry { T = TypeVar(\"\" \"T\", covariant=False, contravariant=False); }\n"
            + "class Box(Generic[T]) { def identity(self: Box, value: T) -> T { return value; } }\n",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}

"""Test TypeVar validation errors (Pyright: createTypeVarType, assignTypeToExpression)."""
test "typevar1_validation_errors" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar1.jac"));

    assert len(program.errors_had) == 3 , f"Expected 3 errors, got {len(
        program.errors_had
    )}";

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    assert 'TypeVar name "T3"' in all_errors and 'must match' in all_errors , "Expected name mismatch error for T2 = TypeVar('T3')";
    assert 'must be assigned to a simple variable' in all_errors , "Expected index expression error for my_dict['var'] = TypeVar('T5')";
    assert 'requires at least two constrained types' in all_errors , "Expected single constraint error for TypeVar('T5', str)";
}


"""Test TypeVar scope validation errors (Pyright: typeVar3.py)."""
test "typevar3_scope_errors" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar3.jac"));

    assert len(program.errors_had) == 12 , f"Expected 12 TypeVar scope errors, got {len(
        program.errors_had
    )}";

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    assert 'is already in use by an outer scope' in all_errors , "Expected error for nested class reusing outer TypeVar (e.g. InnerClass1 reuses _T)";
    assert 'has no meaning in this context' in all_errors , "Expected error for TypeVar used outside its valid scope";
}

"""Test TypeVar variance validation (Pyright: covariant/contravariant checks)."""
test "typevar4_variance_validation" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar4.jac"));

    # 5 errors: covariant in param, contravariant in returns (explicit + inferred)
    assert len(program.errors_had) == 5 , f"Expected 5 errors, got {len(
        program.errors_had
    )}";

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    # Covariant in parameter error
    assert "Covariant type variable cannot be used in parameter type" in all_errors , "Expected covariant param error for func2(a: _T_co)";

    # Contravariant in return errors
    assert "Contravariant type variable cannot be used in return type" in all_errors , "Expected contravariant return error";
}

"""Test unbounded TypeVar operation validation (Pyright: typeVar5)."""
test "typevar5_unbounded_operations" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar5.jac"));

    # 18 errors: 9 per function (attribute, call, subscript, attribute, binary,
    # unary, augmented assignment, await, iteration)
    assert len(program.errors_had) == 18 , f"Expected 18 errors, got {len(
        program.errors_had
    )}";

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    # Attribute access errors
    assert 'Cannot access attribute "temp" for type "_T1"' in all_errors , "Expected attribute access error for a.temp";

    # Not callable errors
    assert 'Type "_T1" is not callable' in all_errors , "Expected callable error for a(3)";

    # Not subscriptable errors
    assert 'Type "_T1" is not subscriptable' in all_errors , "Expected subscript error for a[0]";

    # Binary operator errors
    assert 'Operator "__add__' in all_errors
        and 'not supported for type' in all_errors , "Expected binary op error for a + 1";

    # Unary operator errors
    assert 'Operator "__neg__' in all_errors
        and 'not supported for type' in all_errors , "Expected unary op error for -a";

    # Await errors
    assert 'Type "_T1" is not awaitable' in all_errors , "Expected await error for await a";

    # Iteration errors
    assert 'Type "_T1" is not iterable' in all_errors , "Expected iteration error for for _ in a";
}

"""Test bounded TypeVar operation validation (Pyright: typeVar6)."""
test "typevar6_bounded_operations" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar6.jac"));

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    # func1 (_T1, bound=Foo): var2 missing, wrong call arg type, no subscript,
    # no binary op, no unary op, no aug-assign, no await, no iter, no do_other_stuff
    # = 9 errors
    assert 'Cannot access attribute "var2"' in all_errors , "Expected attribute error for a.var2 (Foo has no var2)";
    assert 'is not subscriptable' in all_errors , "Expected subscript error for a[0]";
    assert 'is not awaitable' in all_errors , "Expected await error for await a";
    assert 'is not iterable' in all_errors , "Expected iteration error for for _ in a";
    assert 'Cannot access attribute "do_other_stuff"' in all_errors , "Expected error for a.do_other_stuff() on Foo-bounded T1";
}

"""Test constrained TypeVar operation validation."""
test "typevar7_constrained_operations" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar7.jac"));

    error_messages = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(error_messages);

    # Key TypeVar-related errors to verify (constraints check each type)
    # Attribute access - Foo doesn't have var2
    assert 'Cannot access attribute "var2" for type "Foo"' in all_errors , "Expected attribute error for a.var2 (Foo has no var2)";

    # Subscript - neither Foo nor Bar is subscriptable
    assert 'is not subscriptable' in all_errors , "Expected subscript error for a[0]";

    # Unary operator - neither Foo nor Bar supports __neg__
    assert '__neg__' in all_errors and 'not supported' in all_errors , "Expected unary op error for -a";

    # Await - neither Foo nor Bar is awaitable
    assert 'is not awaitable' in all_errors , "Expected await error for await a";

    # Iteration - neither Foo nor Bar is iterable
    assert 'is not iterable' in all_errors , "Expected iteration error for for _ in a";

    # Method access - Foo doesn't have do_other_stuff
    assert 'Cannot access attribute "do_other_stuff" for type "Foo"' in all_errors , "Expected error for a.do_other_stuff() on Foo constraint";
}

"""Test that ParamSpec and TypeVarTuple in Callable annotations produce no false E1071 errors."""
test "paramspec_callable_no_false_e1071" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "paramspec.jac"));

    errors = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(errors);

    e1071_errors = [
        e
        for e in errors
        if "E1071" in e
    ];
    assert len(e1071_errors) == 0 , f"Expected no E1071 errors for Callable[P, T], got:\n{all_errors}";
}

"""Test constrained TypeVars with ellipsis stub bodies (Pyright: typeVar10.py)."""
test "typevar10_ellipsis_stub_no_error" {
    program = JacProgram();
    mod = program.compile(os.path.join(TYPEVAR_FIXTURES, "typeVar10.jac"));

    errors = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(errors);

    # Ellipsis-only stub methods should not trigger E1004
    e1004_errors = [
        e
        for e in errors
        if "E1004" in e
    ];
    assert len(e1004_errors) == 0 , f"Expected no E1004 for ellipsis stubs, got:\n{all_errors}";
}

"""Mutable generic containers require invariant type arguments."""
test "invariant_generic_arguments" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_invariant_generics.jac")
    );

    errors = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(errors);

    assert len(errors) == 7 , f"Expected 7 invariant generic errors, got:\n{all_errors}";
    assert all_errors.count("Cannot assign") == 7 , f"Expected all seven container substitutions to be rejected, got:\n{all_errors}";
}

"""Test that module-level dunder variables (__name__, __file__, etc.) type-check cleanly."""
test "module_dunders_no_errors" {
    program = JacProgram();
    mod = program.compile(os.path.join(CHECKER_FIXTURES, "module_dunders.jac"));

    errors = [e.pretty_print() for e in program.errors_had];
    all_errors = "\n".join(errors);

    assert len(program.errors_had) == 0 , f"Expected no errors for module dunder variables, got:\n{all_errors}";
}

test "isinstance narrows a class or variadic tuple of generic classes" {
    program = JacProgram();
    program.compile(
        file_path="generic_class_guard.jac",
        use_str="def select[T: object](value: object, kinds: type[T] | tuple[type[T], ...]) -> list[T] { result: list[T] = []; if isinstance(value, kinds) { result.append(value); } return result; }",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}

test "bounded generic union branches accept containers and None" {
    program = JacProgram();
    program.compile(
        file_path="generic_optional_branch.jac",
        use_str="node Part {} def consume[T: Node](value: T | list[T] | None) -> None {} with entry { consume(Part()); consume([Part()]); consume(None); }",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}

test "opaque iterable alternatives preserve gradual generic arguments" {
    program = JacProgram();
    program.compile(
        file_path="generic_opaque_iterable.jac",
        use_str="def consume(values: list[str]) -> None {} def forward(value: any) -> None { consume(list(value or [])); }",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}

test "generic method specialization preserves asynchronous call results" {
    program = JacProgram();
    program.compile(
        file_path="generic_async_method.jac",
        use_str="import asyncio; obj Service[T] { async def fetch(value: T) -> T { return value; } } def schedule(service: Service[int]) -> None { asyncio.ensure_future(service.fetch(1)); }",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}

test "async generator methods retain their iterator result after specialization" {
    program = JacProgram();
    program.compile(
        file_path="generic_async_generator.jac",
        use_str="""
obj Source[T] {
    async def values(value: T) -> AsyncIterator[T];
    async def opaque(value: T) -> any { yield value; }
    async def factory(value: T) -> AsyncIterator[T] { return self.values(value); }
}
impl Source.values(value: T) -> AsyncIterator[T] { yield value; }
async def consume(source: Source[int]) -> None {
    async for value in source.values(1) { result: int = value; }
    async for value in source.opaque(2) { result: int = value; }
    async for value in await source.factory(3) { result: int = value; }
}
""",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}

test "an async function returning an iterator still requires awaiting" {
    program = JacProgram();
    program.compile(
        file_path="async_iterator_factory.jac",
        use_str="""
async def values -> AsyncIterator[int] { yield 1; }
async def factory -> AsyncIterator[int] { return values(); }
async def wrong -> None { async for value in factory() { print(value); } }
""",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert any(error.code?.code == "E1022" for error in program.errors_had);
}

test "a nested generator does not change the enclosing function return contract" {
    program = JacProgram();
    program.compile(
        file_path="nested_generator_return.jac",
        use_str="""
import from typing { Generator }
def outer -> Generator {
    def inner -> Generator { yield 1; }
    report inner();
}
""",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert any(error.code?.code == "E1004" for error in program.errors_had) , [
        str(error) for error in program.errors_had
    ];
}

test "runtime class guards refine class objects and callable instances" {
    program = JacProgram();
    program.compile(
        file_path="runtime_class_guards.jac",
        use_str="""
import from enum { Enum }
import from types { MethodType }
def names(ty: object) -> list[str] {
    if isinstance(ty, type) and issubclass(ty, Enum) {
        return [member.name for member in ty];
    }
    return [];
}
def receiver(caller: Callable) -> object {
    value: object = caller;
    if isinstance(value, MethodType) { return value.__self__; }
    return None;
}
def dynamic(value: object, kind: any) -> any {
    if isinstance(value, kind) { return value.payload; }
    return None;
}
def guarded_class(lookup: Callable[(..., any)]) -> type[Enum] | None {
    value = lookup();
    if not (isinstance(value, type) and issubclass(value, Enum)) { return None; }
    return value;
}
def guarded_classes(values: list[object]) -> list[type[Enum]] {
    result: list[type[Enum]] = [];
    for value in values {
        if not (isinstance(value, type) and issubclass(value, Enum)) { continue; }
        result.append(value);
    }
    return result;
}
def select[T](values: list[object], kinds: type[T] | tuple[type[T], ...]) -> list[T] {
    return [value for value in values if isinstance(value, kinds)];
}
obj Item { has value: int = 0; }
obj DefaultItem(Item) {}
def annotation_tuple(value: str) -> (str, dict | None) { return (value, None); }
def class_tuple_key(table: dict[tuple[type[Item]], str]) -> str { return table[(Item,)]; }
def class_names -> list[str] { return [cls.__name__ for cls in (Item, DefaultItem)]; }
def materialize(value: type[Item] | Item | None) -> Item {
    kind = value or DefaultItem;
    return kind() if isinstance(kind, type) else kind;
}
def construct(flag: bool) -> Item {
    kind = Item if flag else DefaultItem;
    return kind();
}
def construct_generic[T: Item](kind: type[T]) -> T { return kind(); }
def collected_class_names(values: list[object]) -> list[str] {
    classes = [value for value in values if isinstance(value, type) and issubclass(value, Item)];
    ordered = sorted(classes, key=lambda (cls: type[Item]) { cls.__name__; });
    names = [cls.__name__ for cls in ordered];
    names += [cls.__name__ for cls in (Item, DefaultItem)];
    names += [cls.__name__ for cls in {Item, DefaultItem}];
    names += [cls.__name__ for cls in {"item": Item}.values()];
    names += [cls.__name__ for cls in (kind for kind in classes)];
    return names;
}
""",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}

test "a union constructor call must satisfy every possible constructor" {
    program = JacProgram();
    program.compile(
        file_path="union_constructor_args.jac",
        use_str="""
obj Number { has value: int; }
obj Text { has value: str; }
def wrong(flag: bool) -> None {
    kind = Number if flag else Text;
    kind(1);
}
""",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert any(error.code?.code == "E1053" for error in program.errors_had);
}

test "dynamic class guards keep the negative branch reachable" {
    for annotation in ["type[Item]", "tuple[type[Item], ...]"] {
        program = JacProgram();
        program.compile(
            file_path="dynamic_class_negative.jac",
            use_str="obj Item {}\n"
                + "def wrong(value: Item, kinds: "
                + annotation
                + ") -> str {\n"
                + "    if isinstance(value, Item) and isinstance(value, kinds) { return \"matched\"; }\n"
                + "    return value;\n}\n",
            options=CompileOptions(
                no_cgen=True, no_ir_cache=True, force_codespace="server"
            )
        );
        assert any(error.code?.code == "E1002" for error in program.errors_had);
    }
}

test "union members preserve inherited overloads and generic return types" {
    imports = "import sys;\nimport from io { StringIO }\nimport from typing { TextIO }\n";
    program = JacProgram();
    program.compile(
        file_path="union_text_stream.jac",
        use_str=imports
            + """
def read_text(stream: TextIO | StringIO) -> str {
    sys.stderr.write("ready");
    stream.write("text");
    return stream.read();
}

""",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
    bad = JacProgram();
    bad.compile(
        file_path="union_text_stream_bytes.jac",
        use_str=imports
            + """
def wrong(stream: TextIO | StringIO) -> None {
    stream.write(b"bytes");
}
""",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert any(error.code?.code in ("E1049", "E1053") for error in bad.errors_had);
}

test "class unions retain classmethod lookup" {
    program = JacProgram();
    program.compile(
        file_path="union_classmethods.jac",
        use_str="""
obj Base {
    @classmethod
    def make(cls: type[Base]) -> Base { return cls(); }
}
obj First(Base) {}
obj Second(Base) {}
def build -> list[Base] { return [cls.make() for cls in (First, Second)]; }
""",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , "\n".join(
        error.pretty_print() for error in program.errors_had
    );
}
