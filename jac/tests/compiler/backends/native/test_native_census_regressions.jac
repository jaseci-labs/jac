"""Programs the tier census found printing something other than Python, or
refused where they need not be.

A variadic tuple is stored as a list, and printed as one ("[7, 8]"); a `Node`
ability saw each node as the int handle the graph engine passes ("int"); an
expression statement holding a comprehension had no type and was refused, and
so was `hasattr`. An any value stored into a container whose element type was
inferred from a literal went into a slot of that type, so a string printed as
its address: that store is refused now.
"""
import os;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { assert_native_identity }

glob FIXTURES: str = str(Path(__file__).resolve().parent / "fixtures");

test "a variadic tuple prints as a tuple on the native tier" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "census_var_tuple.jac"), profiles=["managed"]
    );
    assert out.splitlines()[0] == "(7, 8)" , out;
    assert out.splitlines()[2] == "(5,)" , out;
}

test "a Node ability sees the concrete type of each node" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "census_node_type_name.jac"), profiles=["managed"]
    );
    assert out.strip() == "3 ['Hall', 'Room', 'Room']" , out;
}

test "dropped comprehensions run and hasattr lowers on the native tier" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "census_expr_stmt.jac"), profiles=["managed"]
    );
    assert out.splitlines()[0] == "[0, 1, 2, 0, 10]" , out;
}

test "an any value stored into a literal-inferred container is refused" {
    prog = JacProgram();
    prog.compile(
        os.path.join(FIXTURES, "census_inferred_any_store.jac"),
        options=CompileOptions(native_required=True, no_ir_cache=True)
    );
    messages = [e.pretty_print() for e in prog.errors_had];
    assert any("inferred as" in m and "mydict" in m for m in messages) , messages;
}
