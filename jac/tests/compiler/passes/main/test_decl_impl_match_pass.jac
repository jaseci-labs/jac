"""Declaration/implementation match pass tests – migrated from test_decl_impl_match_pass.py.

Tests that declaration-implementation matching works correctly: parameter
count mismatches are detected, abilities are connected to declarations,
and impl body symbols are resolved.
"""

import io;
import sys;
import os;
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang { JacRuntime as Jac }
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     ),
     EXAMPLES = os.path.join(JAC_ROOT, "examples");

"""Helper to import a jac module and capture its stdout."""
def run_jac_import(target: str, base_path: str) -> str {
    old_stdout = sys.stdout;
    buf = io.StringIO();
    sys.stdout = buf;
    try {
        Jac.jac_import(target=target, base_path=base_path);
    } finally {
        sys.stdout = old_stdout;
    }
    return buf.getvalue();
}

test "parameter count mismatch" {
    (out := JacProgram()).compile(os.path.join(FIXTURES, "defn_decl_mismatch.jac"));

    expected_stdout_values = (
        "Parameter count mismatch for ability impl.SomeObj.foo.",
        "    6 |",
        "    7 | # Miss match parameter count.",
        "    8 | impl SomeObj.foo(param1: str) -> str {",
        "      |      ^^^^^^^^^^^",
        '    9 |     return "foo";',
        "   10 | }",
        "From the declaration of foo.",
        "    1 | obj SomeObj {",
        "    2 |     def foo(param1: str, param2: int) -> str;",
        "      |         ^^^",
        "    3 |     def bar(param1: str, param2: int) -> str;",
        "    4 |     def baz -> str;",
        "Parameter count mismatch for ability impl.SomeObj.baz.",
        "   17 | # Explicit self when decl has no params.",
        "   18 | impl SomeObj.baz(self: SomeObj) -> str {",
        "      |      ^^^^^^^^^^^",
        "From the declaration of baz.",
        "    4 |     def baz -> str;",
        "      |         ^^^"
    );

    errors_output = "";
    for error in out.errors_had {
        errors_output += error.pretty_print() + "\n";
    }

    for exp in expected_stdout_values {
        assert exp in errors_output , f"Expected error text not found: {exp}";
    }
}

test "ability connected to decl" {
    state = (out := JacProgram()).compile(os.path.join(FIXTURES, "base.jac"));
    assert not out.errors_had;
    assert "impl.Test.say_hi" in state.impl_mod[0].sym_tab.names_in_scope;
    say_hi_node = (
        state.impl_mod[0].sym_tab.names_in_scope["impl.Test.say_hi"].decl.name_of
    );
    assert isinstance(say_hi_node, uni.ImplDef) and say_hi_node.body is not None;
    assert "impl.Test.init" in state.impl_mod[0].sym_tab.names_in_scope;
    init_node = state.impl_mod[0].sym_tab.names_in_scope["impl.Test.init"].decl.name_of;
    assert isinstance(init_node, uni.ImplDef) and init_node.body is not None;
}

test "ability connected to decl post" {
    state = (out := JacProgram()).compile(os.path.join(FIXTURES, "base2.jac"));
    assert not out.errors_had;
    assert "impl.Test.say_hi" in state.impl_mod[0].sym_tab.names_in_scope;
    say_hi_node = (
        state.impl_mod[0].sym_tab.names_in_scope["impl.Test.say_hi"].decl.name_of
    );
    assert isinstance(say_hi_node, uni.ImplDef) and say_hi_node.body is not None;
    assert "impl.Test.init" in state.impl_mod[0].sym_tab.names_in_scope;
    init_node = state.impl_mod[0].sym_tab.names_in_scope["impl.Test.init"].decl.name_of;
    assert isinstance(init_node, uni.ImplDef) and init_node.body is not None;
}

test "run base2" {
    output = run_jac_import("base2", os.path.join(FIXTURES, "./"));
    assert "56" in output;
}

test "arch ref has sym" {
    state = JacProgram().compile(os.path.join(FIXTURES, "defs_and_uses.jac"));
    for i in state.get_all_sub_nodes(uni.ImplDef) {
        assert i.sym is not None , f"ImplDef {i.sym_name} has no sym";
    }
}

test "single impl annex" {
    mypass = JacProgram().compile(
        os.path.join(EXAMPLES, "manual_code", "circle_pure.jac")
    );
    assert mypass.impl_mod[0].pp().count("ImplDef - impl.Circle.area") == 1;
}

test "impl decl resolution fix" {
    output = run_jac_import("mtest", os.path.join(FIXTURES, "./"));
    assert "2.0\n" in output;
}

test "impl grab" {
    output = run_jac_import("impl_grab", os.path.join(FIXTURES, "./"));
    assert "1.414" in output;
}

test "nested impls" {
    output = run_jac_import("nested_impls", os.path.join(FIXTURES, "./"));
    lines = output.split("\n");
    assert "Hello,from bar in kk" in lines[0];
    assert "Greeting: Hello, World!" in lines[1];
    assert "Repeated: Hello" in lines[2];
    assert "Hello, World!" in lines[3];
    assert "Last message:!" in lines[4];
    assert "Final message:!" in lines[5];
}

test "abstraction bug" {
    output = run_jac_import("atest", os.path.join(FIXTURES, "./"));
    assert output == "42\n";
}

test "inner mod impl" {
    output = run_jac_import("enumerations", os.path.join(FIXTURES, "./"));
    assert output == "1\n";
}

test "impl body symbol resolution" {
    state = (out := JacProgram()).compile(
        os.path.join(FIXTURES, "impl_symbol_resolution.jac")
    );
    assert not out.errors_had , f"Compilation errors: {out.errors_had}";

    # Find the impl module
    assert len(state.impl_mod) == 1 , "Expected one impl module";
    impl_mod = state.impl_mod[0];

    # Get the ImplDef nodes
    impl_defs = [
        node
        for node in impl_mod.get_all_sub_nodes(uni.ImplDef)
        if isinstance(node, uni.ImplDef)
    ];
    assert len(impl_defs) == 2 , f"Expected 2 ImplDef nodes, got {len(impl_defs)}";

    # Check that AtomTrailer chains (self.count, self.name) have their first
    # element (self) resolved
    for impl_def in impl_defs {
        atom_trailers = impl_def.get_all_sub_nodes(uni.AtomTrailer);
        assert len(atom_trailers) > 0 , (
            f"Expected AtomTrailer nodes in {impl_def.sym_name}"
        );

        for trailer in atom_trailers {
            chain = trailer.as_attr_list;
            if chain and chain[0].sym_name == "self" {
                assert chain[0].sym is not None , (
                    f"'self' in chain not resolved in {impl_def.sym_name}"
                );
                assert chain[0].sym.sym_name == "self" , (
                    f"Expected 'self' symbol, got {chain[0].sym.sym_name}"
                );
            }
        }
    }
}
