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
        os.path.join(FIXTURES, "impl_symbol_resolution.jac"), type_check=True
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

test "impl has var type not shadowed" {
    # Verifies that `has tasks: list` retains its type when reassigned
    # in an impl file (e.g., `tasks = tasks + [task]`). Without the
    # _fix_shadowed_parent_symbols fix, SymTabBuildPass creates an untyped
    # local var that shadows the typed HasVar from the parent scope.
    state = (out := JacProgram()).compile(
        os.path.join(FIXTURES, "impl_has_var_type_shadow.jac")
    );
    assert not out.errors_had , f"Compilation errors: {out.errors_had}";
    assert len(state.impl_mod) == 1 , "Expected one impl module";
    impl_mod = state.impl_mod[0];

    # Find the add_task ImplDef (the one with the assignment).
    impl_defs = [
        node
        for node in impl_mod.get_all_sub_nodes(uni.ImplDef)
        if isinstance(node, uni.ImplDef) and "add_task" in node.sym_name
    ];
    assert len(impl_defs) == 1 , f"Expected 1 add_task ImplDef, got {len(impl_defs)}";
    add_task_impl = impl_defs[0];

    # Find all Name nodes referencing "tasks" in the impl body.
    task_names = [
        n
        for n in add_task_impl.get_all_sub_nodes(uni.Name)
        if isinstance(n, uni.Name) and n.value == "tasks"
    ];
    assert len(task_names) > 0 , "Expected Name nodes for 'tasks'";

    # Every reference to "tasks" must resolve to the HasVar symbol,
    # not an untyped local var.
    for name_node in task_names {
        assert name_node.sym is not None , (
            "'tasks' Name node has no symbol — resolution failed"
        );
        assert not isinstance(name_node.sym.decl.name_of, uni.HasVar) , (
            f"'tasks' should not resolve to HasVar, got "
            f"{type(name_node.sym.decl.name_of).__name__}"
        );
    }
}

test "class reassignment impl match" {
    # Bug: class reassignment via tuple unpacking creates second defn (Name node).
    # lookup.defn[-1] returned Name instead of Archetype, causing E2009.
    state = (out := JacProgram()).compile(
        os.path.join(FIXTURES, "multi_inherit_impl_match.jac")
    );
    assert not [
        e
        for e in out.errors_had
        if "E2009" in str(e)
    ];
    assert "impl.MyClass.get_value" in state.sym_tab.names_in_scope;
}

test "E2016 impl for method with full body" {
    state = (out := JacProgram()).compile(
        os.path.join(FIXTURES, "fullbody_impl_error.jac")
    );

    e2016_errors = [
        e
        for e in out.errors_had
        if "E2016" in e.pretty_print()
    ];
    assert len(e2016_errors) == 2 , (
        f"Expected 2 E2016 errors (make + clone), got {len(e2016_errors)}"
    );

    errors_output = "";
    for error in e2016_errors {
        errors_output += error.pretty_print() + "\n";
    }

    # Find the Foo archetype's abilities
    for node in state.get_all_sub_nodes(uni.Ability) {
        if isinstance(node, uni.Ability) and node.sym_name in ("make", "clone") {
            assert not isinstance(node.body, uni.ImplDef) , (
                f"Ability '{node.sym_name}' body was overwritten by impl"
            );
        }
    }

    assert "E2016" in errors_output;
    assert "Cannot provide implementation for a method that already has a body" in errors_output;
    assert "impl Foo.make()" in errors_output;
    assert "impl Foo.clone()" in errors_output;
}

test "E2017 duplicate impl for stub" {
    (out := JacProgram()).compile(os.path.join(FIXTURES, "duplicate_impl_error.jac"));

    e2017_errors = [
        e
        for e in out.errors_had
        if "E2017" in e.pretty_print()
    ];
    assert len(e2017_errors) == 2 , (
        f"Expected 2 E2017 errors (make + clone from .impl file), got {len(
            e2017_errors
        )}"
    );

    errors_output = "";
    for error in e2017_errors {
        errors_output += error.pretty_print() + "\n";
    }

    assert "E2017" in errors_output;
    assert "Duplicate implementation" in errors_output;
}

test "standalone def/obj/node/walker in .impl.jac get symbol resolution" {
    # Regression: the DeclImplMatchPass used to only resolve Load-context
    # names in (TypeAlias, GlobalVars, ModuleCode) subtrees of annex modules,
    # so standalone top-level constructs in a .impl.jac file had their body
    # reads left unresolved — breaking type inference and producing spurious
    # "may be undefined" warnings.
    state = (out := JacProgram()).compile(
        os.path.join(FIXTURES, "standalone_def_in_annex.jac")
    );
    assert len(state.impl_mod) == 1;
    impl_mod = state.impl_mod[0];

    # Collect every Load-context read in the annex whose target is a local
    # assignment (msg / local_label / v / n) and assert each has a resolved sym.
    resolvable = {"msg","local_label","v","n"};
    reads_checked = 0;
    for nm in impl_mod.get_all_sub_nodes(uni.Name, brute_force=True) {
        if nm.value not in resolvable {
            continue;
        }
        is_target = isinstance(nm.parent, uni.Assignment) and nm in nm.parent.target;
        if is_target {
            continue;
        }
        assert nm.sym is not None , (
            f"Read of local '{nm.value}' at line {nm.loc.first_line} "
            f"in .impl.jac has unresolved .sym — resolver skipped this subtree"
        );
        reads_checked += 1;
    }
    assert reads_checked >= 4 , (
        f"Expected >=4 local reads checked (one per construct), got {reads_checked}"
    );
}
