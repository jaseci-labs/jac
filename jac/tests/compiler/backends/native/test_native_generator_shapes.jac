"""Shapes the compiler's own native generator relies on.

Each of these compiled on the native tier and gave a different answer from
the Python tier. They were found by running the generator natively; the
generator's sources are ordinary Jac, so any program could have hit them."""
import from pathlib { Path }
import from tests.support { assert_native_identity }

def fixture(name: str) -> str {
    return str(Path(__file__).resolve().parent / "fixtures" / name);
}

test "a comprehension that repeats one object keeps every element" {
    out = assert_native_identity(
        fixture("comprehension_shared_element.jac"), profiles=["rc", "managed"]
    );
    assert "7 1 2 7 7 7 | 0 9 9 9 | 2 | 58 | 10" in out , out;
}

test "an untyped value compares with an object through the object's __eq__" {
    out = assert_native_identity(
        fixture("any_eq_user_eq.jac"), profiles=["rc", "managed"]
    );
    assert "eq elem-eq rev-eq typed-eq" in out , out;
    assert "ne elem-eq rev-eq typed-eq" in out , out;
    assert "total 800 a" in out , out;
}

test "a caught exception reports its class name" {
    out = assert_native_identity(
        fixture("caught_exception_class_name.jac"), profiles=["rc", "managed"]
    );
    assert "ValueError/boom Trouble/custom IndexError/" in out , out;
    assert "RuntimeError/late none" in out , out;
}

test "a name unpacked from enumerate compares through __eq__" {
    out = assert_native_identity(
        fixture("enumerate_unpacked_eq.jac"), profiles=["rc", "managed"]
    );
    assert "str int ptr" in out , out;
    assert "str other other" in out , out;
}

test "an archetype whose body is an impl block has its fields and methods" {
    out = assert_native_identity(
        fixture("archetype_impl_body.jac"), profiles=["rc", "managed"]
    );
    assert "5 k=5" in out , out;
    assert "1 c=1" in out , out;
    assert "9 4 5" in out , out;
}

"""A `dict[str, str]` and a `dict[str, any]` have different layouts: one holds
pointers, the other boxed values. A conditional expression gives its dict
literal arm the literal's own type, and the result was then handed to the
wider type by a pointer cast, so every later read took a string pointer for a
box. Until that conversion exists the cast is refused by name; the same
literal returned directly takes the wider type and lowers."""
test "a dictionary is refused, not reinterpreted, where boxed values are expected" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from tests.support { native_force_opts }
    options = native_force_opts();
    options.skip_native_engine = True;
    options.no_ir_cache = True;
    program = JacProgram();
    program.compile(file_path=fixture("dict_arm_boxed_values.jac"), options=options);
    refusals = [str(e) for e in program.errors_had];
    assert any("'arm'" in r for r in refusals) , refusals;
    assert not any("'direct'" in r for r in refusals) , refusals;
}

test "an enum whose members come from an impl block has its layout" {
    out = assert_native_identity(
        fixture("enum_impl_body.jac"), profiles=["rc", "managed"]
    );
    assert "dark/1 light/7 True True" in out , out;
    assert "LIGHT HIGH 8" in out , out;
}

"""A name unpacked in a loop header (`for (i, item) in enumerate(items)`, and
the same through `zip` and `dict.items`) was held as an untyped pointer. Passed
to an untyped parameter it was boxed as a string, so `isinstance` on the other
side failed. The compiler's own generic-call solver does this, which left a
type variable unsolved."""
test "an object unpacked in a loop header keeps its class when boxed" {
    out = assert_native_identity(
        fixture("unpacked_object_to_any.jac"), profiles=["rc", "managed"]
    );
    assert "['0:leaf:a', '1:base:b', '2:leaf:c']" in out , out;
    assert "['leaf:a/str:p', 'base:b/str:q', 'leaf:c/str:r']" in out , out;
    assert "['k1=leaf:a', 'k2=base:b']" in out , out;
}
