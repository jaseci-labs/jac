"""Test ast build pass module."""

import ast as ast3
import io
import sys
import types
from collections.abc import Callable

import jaclang.compiler.unitree as uni
from conftest import check_pass_ast_complete, get_micro_jac_files
from jaclang.compiler.passes.main import PyastGenPass
from jaclang.compiler.program import JacProgram


def ast_to_list(node: ast3.AST) -> list[ast3.AST]:
    """Convert ast to list."""
    nodes = [node]
    for _, value in ast3.iter_fields(node):
        if isinstance(value, list):
            for item in value:
                if isinstance(item, ast3.AST):
                    nodes.extend(ast_to_list(item))
        elif isinstance(value, ast3.AST):
            nodes.extend(ast_to_list(value))
    return nodes


def test_pass_ast_complete() -> None:
    """Test for enter/exit name diffs with parser."""
    check_pass_ast_complete(PyastGenPass)


def test_hodge_podge(examples_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    (out := JacProgram()).compile(
        examples_path("micro/hodge_podge.jac"),
    )

    assert not out.errors_had


def test_sem_decorator(fixture_path: Callable[[str], str]) -> None:
    """Test for @_.sem(...) decorator."""
    code_gen = JacProgram().compile(
        fixture_path("codegen_sem.jac"),
    )

    # Function (full).
    sym_fn1 = code_gen.lookup("fn1")
    assert sym_fn1 is not None
    assert sym_fn1.semstr == "A function that takes two integers and returns nothing."
    sym_fn1_table = sym_fn1.symbol_table
    assert sym_fn1_table is not None
    sym_fn1_bar = sym_fn1_table.lookup("bar")
    assert sym_fn1_bar is not None
    assert sym_fn1_bar.semstr == "The first integer parameter."

    # Function (Missing baz)
    sym_fn2 = code_gen.lookup("fn2")
    assert sym_fn2 is not None
    assert sym_fn2.semstr == "A function that takes one integer and returns nothing."
    sym_fn2_table = sym_fn2.symbol_table
    assert sym_fn2_table is not None
    sym_fn2_bar = sym_fn2_table.lookup("bar")
    assert sym_fn2_bar is not None
    assert sym_fn2_bar.semstr == "The first integer parameter."
    sym_fn2_baz = sym_fn2_table.lookup("baz")
    assert sym_fn2_baz is not None
    assert sym_fn2_baz.semstr == ""

    # Function (Without sem at all)
    sym_fn3 = code_gen.lookup("fn3")
    assert sym_fn3 is not None
    assert sym_fn3.semstr == ""
    sym_fn3_table = sym_fn3.symbol_table
    assert sym_fn3_table is not None
    sym_fn3_bar = sym_fn3_table.lookup("bar")
    assert sym_fn3_bar is not None
    assert sym_fn3_bar.semstr == ""
    sym_fn3_baz = sym_fn3_table.lookup("baz")
    assert sym_fn3_baz is not None
    assert sym_fn3_baz.semstr == ""

    # Architype (with body).
    sym_arch1 = code_gen.lookup("Arch1")
    assert sym_arch1 is not None
    assert sym_arch1.semstr == "An object that contains two integer properties."
    sym_arch1_table = sym_arch1.symbol_table
    assert sym_arch1_table is not None
    sym_arch1_bar = sym_arch1_table.lookup("bar")
    assert sym_arch1_bar is not None
    assert sym_arch1_bar.semstr == "The first integer property."
    sym_arch1_baz = sym_arch1_table.lookup("baz")
    assert sym_arch1_baz is not None
    assert sym_arch1_baz.semstr == "The second integer property."

    # Architype (without body).
    sym_arch2 = code_gen.lookup("Arch2")
    assert sym_arch2 is not None
    assert sym_arch2.semstr == "An object that contains two integer properties."
    sym_arch2_table = sym_arch2.symbol_table
    assert sym_arch2_table is not None
    sym_arch2_bar = sym_arch2_table.lookup("bar")
    assert sym_arch2_bar is not None
    assert sym_arch2_bar.semstr == "The first integer property."
    sym_arch2_baz = sym_arch2_table.lookup("baz")
    assert sym_arch2_baz is not None
    assert sym_arch2_baz.semstr == "The second integer property."

    # Enum (with body).
    sym_enum1 = code_gen.lookup("Enum1")
    assert sym_enum1 is not None
    assert sym_enum1.semstr == "An enumeration that defines two values: Bar and Baz."
    sym_enum1_table = sym_enum1.symbol_table
    assert sym_enum1_table is not None
    sym_enum1_bar = sym_enum1_table.lookup("Bar")
    assert sym_enum1_bar is not None
    assert sym_enum1_bar.semstr == "The Bar value of the Enum1 enumeration."
    sym_enum1_baz = sym_enum1_table.lookup("Baz")
    assert sym_enum1_baz is not None
    assert sym_enum1_baz.semstr == "The Baz value of the Enum1 enumeration."

    # Enum (without body).
    sym_enum2 = code_gen.lookup("Enum2")
    assert sym_enum2 is not None
    assert sym_enum2.semstr == "An enumeration that defines two values: Bar and Baz."
    sym_enum2_table = sym_enum2.symbol_table
    assert sym_enum2_table is not None
    sym_enum2_bar = sym_enum2_table.lookup("Bar")
    assert sym_enum2_bar is not None
    assert sym_enum2_bar.semstr == "The Bar value of the Enum2 enumeration."
    sym_enum2_baz = sym_enum2_table.lookup("Baz")
    assert sym_enum2_baz is not None
    assert sym_enum2_baz.semstr == "The Baz value of the Enum2 enumeration."

    if code_gen.gen.py_ast and isinstance(code_gen.gen.py_ast[0], ast3.Module):
        prog = compile(code_gen.gen.py_ast[0], filename="<ast>", mode="exec")
        module = types.ModuleType("__main__")
        module.__dict__["__file__"] = code_gen.loc.mod_path
        exec(prog, module.__dict__)

        # Function (full).
        assert (
            module.fn1._jac_semstr
            == "A function that takes two integers and returns nothing."
        )
        assert module.fn1._jac_semstr_inner["bar"] == "The first integer parameter."
        assert module.fn1._jac_semstr_inner["baz"] == "The second integer parameter."

        # Function (Missing baz)
        assert (
            module.fn2._jac_semstr
            == "A function that takes one integer and returns nothing."
        )
        assert module.fn2._jac_semstr_inner["bar"] == "The first integer parameter."
        assert "baz" not in module.fn2._jac_semstr_inner

        # Function (Without sem at all)
        assert not hasattr(module.fn3, "_jac_semstr")

        # Architype (with body).
        assert (
            module.Arch1._jac_semstr
            == "An object that contains two integer properties."
        )
        assert module.Arch1._jac_semstr_inner["bar"] == "The first integer property."
        assert module.Arch1._jac_semstr_inner["baz"] == "The second integer property."

        # Architype (without body).
        assert (
            module.Arch2._jac_semstr
            == "An object that contains two integer properties."
        )
        assert module.Arch2._jac_semstr_inner["bar"] == "The first integer property."
        assert module.Arch2._jac_semstr_inner["baz"] == "The second integer property."

        # Enum (with body).
        assert (
            module.Enum1._jac_semstr
            == "An enumeration that defines two values: Bar and Baz."
        )
        assert (
            module.Enum1._jac_semstr_inner["Bar"]
            == "The Bar value of the Enum1 enumeration."
        )
        assert (
            module.Enum1._jac_semstr_inner["Baz"]
            == "The Baz value of the Enum1 enumeration."
        )

        # Enum (without body).
        assert (
            module.Enum2._jac_semstr
            == "An enumeration that defines two values: Bar and Baz."
        )
        assert (
            module.Enum2._jac_semstr_inner["Bar"]
            == "The Bar value of the Enum2 enumeration."
        )
        assert (
            module.Enum2._jac_semstr_inner["Baz"]
            == "The Baz value of the Enum2 enumeration."
        )


def test_circle_py_ast(examples_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    code_gen = (out := JacProgram()).compile(
        examples_path("manual_code/circle.jac"),
    )
    if code_gen.gen.py_ast and isinstance(code_gen.gen.py_ast[0], ast3.Module):
        prog = compile(code_gen.gen.py_ast[0], filename="<ast>", mode="exec")
        captured_output = io.StringIO()
        sys.stdout = captured_output
        module = types.ModuleType("__main__")
        module.__dict__["__file__"] = code_gen.loc.mod_path
        exec(prog, module.__dict__)
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        assert "Area of a circle with radius 5 using function: 78" in stdout_value
        assert "Area of a Circle with radius 5 using class: 78" in stdout_value

    assert not out.errors_had


def test_iife_fixture_executes(lang_fixture_path: Callable[[str], str]) -> None:
    """Ensure IIFE and block lambdas lower to executable Python."""
    fixture_path = lang_fixture_path("iife_functions.jac")
    code_gen = (prog := JacProgram()).compile(fixture_path)
    assert not prog.errors_had
    if code_gen.gen.py_ast and isinstance(code_gen.gen.py_ast[0], ast3.Module):
        module_ast = code_gen.gen.py_ast[0]
        compiled = compile(module_ast, filename="<ast>", mode="exec")
        captured = io.StringIO()
        original_stdout = sys.stdout
        try:
            sys.stdout = captured
            module = types.ModuleType("__main__")
            module.__dict__["__file__"] = code_gen.loc.mod_path
            exec(compiled, module.__dict__)
        finally:
            sys.stdout = original_stdout
        output = captured.getvalue()
        assert "Test 1 - Basic IIFE: 42" in output
        assert "Test 6 - IIFE returning function, adder(5): 15" in output
        assert "All IIFE tests completed!" in output


def test_string_literal_import_requires_cl() -> None:
    """Test that string literal imports require cl prefix."""
    # Test that string literal import without cl produces an error
    code = """import from "react-dom" { render }"""
    prog = JacProgram()
    prog.compile(file_path="test.jac", use_str=code)

    # Should have an error about string literals requiring cl
    assert prog.errors_had
    error_messages = [str(e) for e in prog.errors_had]
    assert any(
        "String literal imports" in msg and "client (cl) imports" in msg
        for msg in error_messages
    ), (
        f"Expected error about string literal imports requiring cl, got: {error_messages}"
    )


def test_string_literal_import_works_with_cl() -> None:
    """Test that string literal imports work correctly with cl prefix."""
    # Test that string literal import with cl works
    code = """cl {
    import from "react-dom" { render }
}"""
    prog = JacProgram()
    prog.compile(file_path="test.jac", use_str=code)

    # Should not have errors
    assert not prog.errors_had, (
        f"Unexpected errors: {[str(e) for e in prog.errors_had]}"
    )


def parent_scrub(node: uni.UniNode) -> bool:
    """Validate every node has parent."""
    success = True
    for i in node.kid:
        if not isinstance(i, uni.Module) and i.parent is None:
            success = False
            break
        else:
            success = parent_scrub(i)
    return success


# Micro suite tests - generated dynamically
def pytest_generate_tests(metafunc):
    """Generate test cases for micro jac files."""
    if "micro_jac_file" in metafunc.fixturenames:
        micro_files = get_micro_jac_files()
        metafunc.parametrize("micro_jac_file", micro_files)


def test_micro_suite(micro_jac_file: str) -> None:
    """Parse micro jac file."""
    code_gen = JacProgram().compile(micro_jac_file)
    from_jac_str = ast3.dump(code_gen.gen.py_ast[0], indent=2)
    from_jac = code_gen.gen.py_ast[0]
    assert isinstance(from_jac, ast3.Module)
    try:
        compile(from_jac, filename="<ast>", mode="exec")
    except Exception as e:
        print(from_jac_str)
        raise e
    for i in ast3.walk(from_jac):
        try:
            if not isinstance(i, (ast3.Load, ast3.Store, ast3.Del)):
                assert hasattr(i, "jac_link")
        except Exception as e:
            print(micro_jac_file, ast3.dump(i, indent=2))
            raise e
    assert parent_scrub(code_gen)
    assert len(from_jac_str) > 10


def test_validate_tree_parent_micro_suite(micro_jac_file: str) -> None:
    """Validate every node has parent for micro suite."""
    code_gen = JacProgram().compile(micro_jac_file)
    assert parent_scrub(code_gen)
    code_gen = JacProgram().compile(micro_jac_file)
    assert parent_scrub(code_gen)
