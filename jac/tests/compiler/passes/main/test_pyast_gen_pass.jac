"""PyAST gen pass tests – migrated from test_pyast_gen_pass.py.

Tests for the Python AST generation pass: AST completeness, semantic
decorators, circle execution, micro suite compilation, and parent validation.
"""

import ast as ast3;
import io;
import sys;
import types;
import os;
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { PyastGenPass }
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     ),
     EXAMPLES = os.path.join(JAC_ROOT, "examples"),
     LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

def ast_to_list(`node: ast3.AST) -> list[ast3.AST] {
    nodes = [`node];
    for (_, value) in ast3.iter_fields(`node) {
        if isinstance(value, list) {
            for item in value {
                if isinstance(item, ast3.AST) {
                    nodes.extend(ast_to_list(item));
                }
            }
        } elif isinstance(value, ast3.AST) {
            nodes.extend(ast_to_list(value));
        }
    }
    return nodes;
}


test "hodge podge" {
    (out := JacProgram()).compile(os.path.join(EXAMPLES, "micro", "hodge_podge.jac"));
    assert not out.errors_had;
}

test "super_init_py_to_jac_roundtrip" {
    # Test that super().__init__() works when a Python file goes through Jac's
    # compilation pipeline (Python AST -> Jac IR -> Python AST).
    # This is the jac run <file>.py scenario where __init__ must be preserved.
    code_gen = (prog := JacProgram()).compile(
        os.path.join(FIXTURES, "super_init_base.py")
    );
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    if code_gen.gen.py_ast and isinstance(code_gen.gen.py_ast[0], ast3.Module) {
        compiled = compile(code_gen.gen.py_ast[0], filename="<ast>", mode="exec");
        captured = io.StringIO();
        original_stdout = sys.stdout;
        sys.path.insert(0, FIXTURES);
        try {
            sys.stdout = captured;
            module = types.ModuleType("__main__");
            module.__dict__["__file__"] = code_gen.loc.mod_path;
            exec(compiled, module.__dict__);
        } finally {
            sys.stdout = original_stdout;
            if FIXTURES in sys.path {
                sys.path.remove(FIXTURES);
            }
        }
        output = captured.getvalue();
        # Verify super().__init__() calls work correctly in inheritance chain
        assert "Base init" in output , f"Expected 'Base init' in output, got: {output}";
        assert "Child init" in output , f"Expected 'Child init' in output, got: {output}";
        assert "GrandChild init" in output , f"Expected 'GrandChild init' in output, got: {output}";
        # Verify the order of initialization (base classes init before derived)
        lines = output.strip().split("\n");
        assert lines == [
            "Base init",
            "Child init",
            "Base init",
            "Child init",
            "GrandChild init"
        ] , f"Unexpected initialization order: {lines}";
    }
}

test "sem decorator" {
    code_gen = JacProgram().compile(os.path.join(FIXTURES, "codegen_sem.jac"));

    # Function (full).
    sym_fn1 = code_gen.lookup("fn1");
    assert sym_fn1 is not None;
    assert sym_fn1.semstr == "A function that takes two integers and returns nothing.";
    sym_fn1_table = sym_fn1.symbol_table;
    assert sym_fn1_table is not None;
    sym_fn1_bar = sym_fn1_table.lookup("bar");
    assert sym_fn1_bar is not None;
    assert sym_fn1_bar.semstr == "The first integer parameter.";

    # Function (Missing baz)
    sym_fn2 = code_gen.lookup("fn2");
    assert sym_fn2 is not None;
    assert sym_fn2.semstr == "A function that takes one integer and returns nothing.";
    sym_fn2_table = sym_fn2.symbol_table;
    assert sym_fn2_table is not None;
    sym_fn2_bar = sym_fn2_table.lookup("bar");
    assert sym_fn2_bar is not None;
    assert sym_fn2_bar.semstr == "The first integer parameter.";
    sym_fn2_baz = sym_fn2_table.lookup("baz");
    assert sym_fn2_baz is not None;
    assert sym_fn2_baz.semstr == "";

    # Function (Without sem at all)
    sym_fn3 = code_gen.lookup("fn3");
    assert sym_fn3 is not None;
    assert sym_fn3.semstr == "";
    sym_fn3_table = sym_fn3.symbol_table;
    assert sym_fn3_table is not None;
    sym_fn3_bar = sym_fn3_table.lookup("bar");
    assert sym_fn3_bar is not None;
    assert sym_fn3_bar.semstr == "";
    sym_fn3_baz = sym_fn3_table.lookup("baz");
    assert sym_fn3_baz is not None;
    assert sym_fn3_baz.semstr == "";

    # Architype (with body).
    sym_arch1 = code_gen.lookup("Arch1");
    assert sym_arch1 is not None;
    assert sym_arch1.semstr == "An object that contains two integer properties.";
    sym_arch1_table = sym_arch1.symbol_table;
    assert sym_arch1_table is not None;
    sym_arch1_bar = sym_arch1_table.lookup("bar");
    assert sym_arch1_bar is not None;
    assert sym_arch1_bar.semstr == "The first integer property.";
    sym_arch1_baz = sym_arch1_table.lookup("baz");
    assert sym_arch1_baz is not None;
    assert sym_arch1_baz.semstr == "The second integer property.";

    # Architype (without body).
    sym_arch2 = code_gen.lookup("Arch2");
    assert sym_arch2 is not None;
    assert sym_arch2.semstr == "An object that contains two integer properties.";
    sym_arch2_table = sym_arch2.symbol_table;
    assert sym_arch2_table is not None;
    sym_arch2_bar = sym_arch2_table.lookup("bar");
    assert sym_arch2_bar is not None;
    assert sym_arch2_bar.semstr == "The first integer property.";
    sym_arch2_baz = sym_arch2_table.lookup("baz");
    assert sym_arch2_baz is not None;
    assert sym_arch2_baz.semstr == "The second integer property.";

    # Enum (with body).
    sym_enum1 = code_gen.lookup("Enum1");
    assert sym_enum1 is not None;
    assert sym_enum1.semstr == "An enumeration that defines two values: Bar and Baz.";
    sym_enum1_table = sym_enum1.symbol_table;
    assert sym_enum1_table is not None;
    sym_enum1_bar = sym_enum1_table.lookup("Bar");
    assert sym_enum1_bar is not None;
    assert sym_enum1_bar.semstr == "The Bar value of the Enum1 enumeration.";
    sym_enum1_baz = sym_enum1_table.lookup("Baz");
    assert sym_enum1_baz is not None;
    assert sym_enum1_baz.semstr == "The Baz value of the Enum1 enumeration.";

    # Enum (without body).
    sym_enum2 = code_gen.lookup("Enum2");
    assert sym_enum2 is not None;
    assert sym_enum2.semstr == "An enumeration that defines two values: Bar and Baz.";
    sym_enum2_table = sym_enum2.symbol_table;
    assert sym_enum2_table is not None;
    sym_enum2_bar = sym_enum2_table.lookup("Bar");
    assert sym_enum2_bar is not None;
    assert sym_enum2_bar.semstr == "The Bar value of the Enum2 enumeration.";
    sym_enum2_baz = sym_enum2_table.lookup("Baz");
    assert sym_enum2_baz is not None;
    assert sym_enum2_baz.semstr == "The Baz value of the Enum2 enumeration.";

    if code_gen.gen.py_ast and isinstance(code_gen.gen.py_ast[0], ast3.Module) {
        prog = compile(code_gen.gen.py_ast[0], filename="<ast>", mode="exec");
        module = types.ModuleType("__main__");
        module.__dict__["__file__"] = code_gen.loc.mod_path;
        exec(prog, module.__dict__);
        # Function (full).
        assert (
            module.fn1._jac_semstr == "A function that takes two integers and returns nothing."
        );
        assert module.fn1._jac_semstr_inner["bar"] == "The first integer parameter.";
        assert module.fn1._jac_semstr_inner["baz"] == "The second integer parameter.";
        # Function (Missing baz)
        assert (
            module.fn2._jac_semstr == "A function that takes one integer and returns nothing."
        );
        assert module.fn2._jac_semstr_inner["bar"] == "The first integer parameter.";
        assert "baz" not in module.fn2._jac_semstr_inner;
        # Function (Without sem at all)
        assert not hasattr(module.fn3, "_jac_semstr");
        # Architype (with body).
        assert (
            module.Arch1._jac_semstr == "An object that contains two integer properties."
        );
        assert module.Arch1._jac_semstr_inner["bar"] == "The first integer property.";
        assert module.Arch1._jac_semstr_inner["baz"] == "The second integer property.";
        # Architype (without body).
        assert (
            module.Arch2._jac_semstr == "An object that contains two integer properties."
        );
        assert module.Arch2._jac_semstr_inner["bar"] == "The first integer property.";
        assert module.Arch2._jac_semstr_inner["baz"] == "The second integer property.";
        # Enum (with body).
        assert (
            module.Enum1._jac_semstr == "An enumeration that defines two values: Bar and Baz."
        );
        assert (
            module.Enum1._jac_semstr_inner["Bar"] == "The Bar value of the Enum1 enumeration."
        );
        assert (
            module.Enum1._jac_semstr_inner["Baz"] == "The Baz value of the Enum1 enumeration."
        );
        # Enum (without body).
        assert (
            module.Enum2._jac_semstr == "An enumeration that defines two values: Bar and Baz."
        );
        assert (
            module.Enum2._jac_semstr_inner["Bar"] == "The Bar value of the Enum2 enumeration."
        );
        assert (
            module.Enum2._jac_semstr_inner["Baz"] == "The Baz value of the Enum2 enumeration."
        );
    }
}

test "circle py ast" {
    code_gen = (out := JacProgram()).compile(
        os.path.join(EXAMPLES, "manual_code", "circle.jac")
    );
    if code_gen.gen.py_ast and isinstance(code_gen.gen.py_ast[0], ast3.Module) {
        prog = compile(code_gen.gen.py_ast[0], filename="<ast>", mode="exec");
        captured_output = io.StringIO();
        sys.stdout = captured_output;
        module = types.ModuleType("__main__");
        module.__dict__["__file__"] = code_gen.loc.mod_path;
        exec(prog, module.__dict__);
        sys.stdout = sys.__stdout__;
        stdout_value = captured_output.getvalue();
        assert "Area of a circle with radius 5 using function: 78" in stdout_value;
        assert "Area of a Circle with radius 5 using class: 78" in stdout_value;
    }
    assert not out.errors_had;
}

test "iife fixture executes" {
    fixture_path = os.path.join(LANG_FIXTURES, "iife_functions.jac");
    code_gen = (prog := JacProgram()).compile(fixture_path);
    assert not prog.errors_had;
    if code_gen.gen.py_ast and isinstance(code_gen.gen.py_ast[0], ast3.Module) {
        module_ast = code_gen.gen.py_ast[0];
        compiled = compile(module_ast, filename="<ast>", mode="exec");
        captured = io.StringIO();
        original_stdout = sys.stdout;
        try {
            sys.stdout = captured;
            module = types.ModuleType("__main__");
            module.__dict__["__file__"] = code_gen.loc.mod_path;
            exec(compiled, module.__dict__);
        } finally {
            sys.stdout = original_stdout;
        }
        output = captured.getvalue();
        assert "Test 1 - Basic IIFE: 42" in output;
        assert "Test 6 - IIFE returning function, adder(5): 15" in output;
        assert "All IIFE tests completed!" in output;
    }
}

test "string literal import requires cl" {
    code = """import from "react-dom" { render }""";
    prog = JacProgram();
    prog.compile(file_path="test.jac", use_str=code);
    assert prog.errors_had;
    error_messages = [str(e) for e in prog.errors_had];
    assert any(
        "String literal imports" in msg and "client (cl) imports" in msg
        for msg in error_messages
    ) , (
        f"Expected error about string literal imports requiring cl, got: {error_messages}"
    );
}

test "string literal import works with cl" {
    code = """cl {
    import from "react-dom" { render }
}""";
    prog = JacProgram();
    prog.compile(file_path="test.jac", use_str=code);
    assert not prog.errors_had , (
        f"Unexpected errors: {[str(e) for e in prog.errors_had]}"
    );
}

test "match case empty wildcard body compiles" {
    code = """
with entry {
    x = 42;
    match x {
        case 1: print("one");
        case _:;
    }
}
""";
    prog = JacProgram();
    prog.compile(file_path="test_match.jac", use_str=code);
    assert not prog.errors_had , (
        f"Match with empty wildcard body should compile cleanly, "
        f"got: {[str(e) for e in prog.errors_had]}"
    );
}

test "py_ast_val raises ICE with source location on empty py_ast" {
    code = """with entry { x = 1; }""";
    prog = JacProgram();
    mod = prog.compile(file_path="test_ice.jac", use_str=code);
    # Get the PyastGenPass instance from child passes
    pyast_pass = PyastGenPass(ir_in=mod, prog=prog);
    # Create a node with empty py_ast by using an existing node and clearing it
    target_node = mod;
    original = target_node.gen.py_ast[:];
    target_node.gen.py_ast = [];
    try {
        pyast_pass.py_ast_val(target_node);
        assert False , "Expected RuntimeError from py_ast_val";
    } except RuntimeError as e {
        msg = str(e);
        assert "Internal Compiler Error" in msg , (
            f"ICE should mention 'Internal Compiler Error', got: {msg}"
        );
        assert "PyastGenPass" in msg , (f"ICE should mention the pass name, got: {msg}");
        assert "Empty py_ast" in msg , (
            f"ICE should mention 'Empty py_ast', got: {msg}"
        );
        assert "Module" in msg , (f"ICE should mention the node type, got: {msg}");
        assert "test_ice.jac" in msg , (
            f"ICE should mention the source file, got: {msg}"
        );
        # Verify file:line:col format is present
        import re;
        assert re.search(r"test_ice\.jac:\d+:\d+", msg) , (
            f"ICE should contain file:line:col location, got: {msg}"
        );
    } finally {
        target_node.gen.py_ast = original;
    }
}
