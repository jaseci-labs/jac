"""Test ECMAScript AST generation using consolidated Jac fixtures."""

import json
from collections.abc import Callable, Iterable
from pathlib import Path

import pytest

from jaclang.compiler.passes.ecmascript import EsastGenPass, es_node_to_dict
from jaclang.compiler.passes.ecmascript import estree as es
from jaclang.compiler.passes.ecmascript.es_unparse import es_to_js
from jaclang.pycore.program import JacProgram


@pytest.fixture
def fixture_path() -> Callable[[str], str]:
    """Return a function that returns absolute path to a fixture file."""

    def _get_fixture_path(filename: str) -> str:
        fixtures_dir = Path(__file__).parent / "fixtures"
        return str(fixtures_dir / filename)

    return _get_fixture_path


def walk_es_nodes(node: es.Node) -> Iterable[es.Node]:
    """Yield every ESTree node in a depth-first traversal."""
    yield node
    for value in vars(node).values():
        if isinstance(value, es.Node):
            yield from walk_es_nodes(value)
        elif isinstance(value, list):
            for item in value:
                if isinstance(item, es.Node):
                    yield from walk_es_nodes(item)


def compile_to_esast(filename: str) -> es.Program:
    """Compile Jac source to an ESTree program."""
    prog = JacProgram()
    ir = prog.compile(file_path=filename, no_cgen=True)

    assert not prog.errors_had, (
        f"Compilation errors in {filename}: {[str(e) for e in prog.errors_had]}"
    )

    es_pass = EsastGenPass(ir, prog)
    es_ir = es_pass.ir_out

    assert hasattr(es_ir.gen, "es_ast"), "es_ast attribute missing"
    assert isinstance(es_ir.gen.es_ast, es.Program)
    return es_ir.gen.es_ast


def test_core_fixture_ast_shape(fixture_path: Callable[[str], str]) -> None:
    """Core fixture should expose fundamental declarations in the ESTree."""
    core_fixture = "core_language_features.jac"
    es_ast = compile_to_esast(fixture_path(core_fixture))

    func_decls = [
        node for node in es_ast.body if isinstance(node, es.FunctionDeclaration)
    ]
    func_names = {func.id.name for func in func_decls if func.id}
    assert {"add", "greet", "fibonacci"}.issubset(func_names)

    class_decls = [
        node for node in es_ast.body if isinstance(node, es.ClassDeclaration)
    ]
    class_names = {cls.id.name for cls in class_decls if cls.id}
    assert "Person" in class_names
    assert "Employee" in class_names

    var_decls = [
        node for node in es_ast.body if isinstance(node, es.VariableDeclaration)
    ]
    assert len(var_decls) >= 2, "Expected const enums and globals"

    ast_json = json.dumps(es_node_to_dict(es_ast))
    assert "TryStatement" in ast_json, "Expected try/except in core fixture"
    assert "BinaryExpression" in ast_json, (
        "Binary expressions should appear in core fixture"
    )


def test_advanced_fixture_contains_async_and_spread_nodes(
    fixture_path: Callable[[str], str],
) -> None:
    """Advanced fixture should surface async, await, and spread constructs."""
    advanced_fixture = "advanced_language_features.jac"
    es_ast = compile_to_esast(fixture_path(advanced_fixture))

    func_names = {
        node.id.name
        for node in es_ast.body
        if isinstance(node, es.FunctionDeclaration) and node.id
    }
    assert "lambda_examples" in func_names
    assert "build_advanced_report" in func_names

    node_types = {type(node).__name__ for node in walk_es_nodes(es_ast)}
    assert "AwaitExpression" in node_types
    assert "SpreadElement" in node_types
    assert "ConditionalExpression" in node_types

    ast_json = json.dumps(es_node_to_dict(es_ast))
    assert "CallExpression" in ast_json
    assert "ReturnStatement" in ast_json


def test_client_fixture_generates_client_bundle(
    fixture_path: Callable[[str], str],
) -> None:
    """Client fixture should retain JSX lowering behaviour."""
    client_fixture = "client_jsx.jac"
    es_ast = compile_to_esast(fixture_path(client_fixture))
    js_code = es_to_js(es_ast)

    assert 'let API_URL = "https://api.example.com";' in js_code, (
        "Client global should use let."
    )
    assert "function component()" in js_code
    assert "__jacJsx" in js_code
    assert "server_only" not in js_code


def test_es_ast_serializes_to_json(fixture_path: Callable[[str], str]) -> None:
    """ESTree should serialize cleanly to JSON for downstream tooling."""
    core_fixture = "core_language_features.jac"
    es_ast = compile_to_esast(fixture_path(core_fixture))
    ast_dict = es_node_to_dict(es_ast)

    serialized = json.dumps(ast_dict)
    assert '"type": "Program"' in serialized
    assert len(serialized) > 1000


def test_class_separate_impl_file(fixture_path: Callable[[str], str]) -> None:
    """Test that separate impl files work correctly for class archetypes."""
    es_ast = compile_to_esast(fixture_path("class_separate_impl.jac"))
    js_code = es_to_js(es_ast)

    # Check that the Calculator class exists
    class_decls = [
        node for node in es_ast.body if isinstance(node, es.ClassDeclaration)
    ]
    class_names = {cls.id.name for cls in class_decls if cls.id}
    assert "Calculator" in class_names
    assert "ScientificCalculator" in class_names

    # Check that methods from impl file are present
    calculator_class = next(
        (cls for cls in class_decls if cls.id and cls.id.name == "Calculator"),
        None,
    )
    assert calculator_class is not None
    assert calculator_class.body is not None
    method_names = {
        m.key.name
        for m in calculator_class.body.body
        if isinstance(m, es.MethodDefinition) and isinstance(m.key, es.Identifier)
    }
    assert "add" in method_names
    assert "multiply" in method_names
    assert "get_value" in method_names

    # Check JavaScript output contains the methods
    assert "class Calculator" in js_code
    assert "class ScientificCalculator" in js_code
    assert "add(" in js_code
    assert "multiply(" in js_code
    assert "power(" in js_code


def test_fstring_generates_template_literal(fixture_path: Callable[[str], str]) -> None:
    """Test that f-strings are converted to JavaScript template literals."""
    advanced_fixture = "advanced_language_features.jac"
    es_ast = compile_to_esast(fixture_path(advanced_fixture))
    js_code = es_to_js(es_ast)

    # Check that template_literal_examples function exists
    func_names = {
        node.id.name
        for node in es_ast.body
        if isinstance(node, es.FunctionDeclaration) and node.id
    }
    assert "template_literal_examples" in func_names

    # Verify TemplateLiteral nodes are present in the AST
    node_types = {type(node).__name__ for node in walk_es_nodes(es_ast)}
    assert "TemplateLiteral" in node_types, (
        "F-strings should be converted to TemplateLiteral nodes"
    )
    assert "TemplateElement" in node_types, (
        "TemplateLiteral should contain TemplateElement nodes"
    )

    # Check that the JavaScript output contains template literal syntax
    assert "`" in js_code, (
        "JavaScript output should contain backtick for template literals"
    )

    # Verify that the f-string variables are interpolated correctly
    # f"{user} scored {score} which is a {status}"
    # Should become something like: `${user} scored ${score} which is a ${status}`
    assert "${" in js_code, "Template literal should contain ${} syntax"


def test_export_semantics_for_pub_declarations(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that :pub annotated declarations generate JavaScript exports."""
    es_ast = compile_to_esast(fixture_path("export_semantics.jac"))
    js_code = es_to_js(es_ast)

    # Verify ExportNamedDeclaration nodes exist in AST
    # Note: cl functions no longer use ES exports — they're registered via
    # __jacRegisterClientModule instead, so only 3 exports (global, class, enum)
    export_decls = [
        node for node in es_ast.body if isinstance(node, es.ExportNamedDeclaration)
    ]
    assert len(export_decls) == 3, "Expected 3 exports (global, class, enum)"

    # Check that public global is exported
    assert "export let PUBLIC_API_URL" in js_code, (
        "Public global should have export keyword"
    )

    # Check that private global is NOT exported
    assert "let PRIVATE_SECRET" in js_code
    assert "export let PRIVATE_SECRET" not in js_code, (
        "Private global should NOT have export keyword"
    )

    # Check that public class is exported
    assert "export class PublicClass" in js_code, (
        "Public class should have export keyword"
    )

    # Check that private class is NOT exported
    assert "class PrivateClass" in js_code
    assert "export class PrivateClass" not in js_code, (
        "Private class should NOT have export keyword"
    )

    # cl functions don't use ES exports — they're registered via
    # __jacRegisterClientModule for global scope compatibility
    assert "function public_function" in js_code
    assert "export function public_function" not in js_code, (
        "cl functions should not have export keyword (uses registration instead)"
    )

    # Check that private function is NOT exported
    assert "function private_function" in js_code
    assert "export function private_function" not in js_code, (
        "Private function should NOT have export keyword"
    )

    # Check that public enum is exported
    assert "export const PublicStatus" in js_code, (
        "Public enum should have export keyword"
    )

    # Check that private enum is NOT exported
    assert "const PrivateStatus" in js_code
    assert "export const PrivateStatus" not in js_code, (
        "Private enum should NOT have export keyword"
    )


def test_reactive_state_generates_use_state(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that has variables in client context generate useState calls."""
    es_ast = compile_to_esast(fixture_path("reactive_state.jac"))
    js_code = es_to_js(es_ast)

    # Check that useState is imported from @jac/runtime (auto-injected)
    assert 'import { useState } from "@jac/runtime"' in js_code, (
        "useState should be auto-imported from @jac/runtime"
    )

    # Check that has declarations generate useState destructuring
    # has count: int = 0; -> const [count, setCount] = useState(0);
    assert "const [count, setCount] = useState(0)" in js_code, (
        "has count should generate useState destructuring"
    )
    assert 'const [name, setName] = useState("test")' in js_code, (
        "has name should generate useState destructuring"
    )

    # Check that assignments to reactive vars generate setter calls
    # count = count + 1; -> setCount(count + 1);
    assert "setCount((count + 1))" in js_code, (
        "Assignment to reactive var should use setter"
    )
    assert "setCount(42)" in js_code, "Direct assignment should use setter"
    assert "setName(" in js_code, "Assignment to name should use setName"


def test_reactive_state_in_cl_jac_file(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that has variables work in .cl.jac files without explicit cl {} wrapper.

    Regression test for bug where has variables only worked inside cl {} blocks
    in .jac files, but failed when defined directly in .cl.jac files.
    """
    es_ast = compile_to_esast(fixture_path("reactive_state.cl.jac"))
    js_code = es_to_js(es_ast)

    # Check that useState is imported from @jac/runtime (auto-injected)
    assert 'import { useState } from "@jac/runtime"' in js_code, (
        "useState should be auto-imported from @jac/runtime in .cl.jac files"
    )

    # Check that has declarations generate useState destructuring
    # has count: int = 0; -> const [count, setCount] = useState(0);
    assert "const [count, setCount] = useState(0)" in js_code, (
        "has count should generate useState destructuring in .cl.jac files"
    )
    assert 'const [name, setName] = useState("test")' in js_code, (
        "has name should generate useState destructuring in .cl.jac files"
    )

    # Check that assignments to reactive vars generate setter calls
    # count = count + 1; -> setCount(count + 1);
    assert "setCount((count + 1))" in js_code, (
        "Assignment to reactive var should use setter in .cl.jac files"
    )
    assert "setCount(42)" in js_code, "Direct assignment should use setter"
    assert "setName(" in js_code, "Assignment to name should use setName"


def test_equivalent_context_patterns(fixture_path: Callable[[str], str]) -> None:
    """Three files with same code but different cl/sv patterns should produce identical output.

    Tests that:
    1. Standard .jac with explicit cl/sv blocks
    2. .cl.jac with default client + explicit sv block
    3. .sv.jac with default server + explicit cl block

    All three should produce identical JavaScript and Python output.
    """
    files = [
        fixture_path("mixed_explicit.jac"),
        fixture_path("mixed_cl_default.cl.jac"),
        fixture_path("mixed_sv_default.sv.jac"),
    ]

    js_outputs = []
    py_outputs = []

    for filepath in files:
        prog = JacProgram()
        # Don't use no_cgen=True since we need Python output
        ir = prog.compile(file_path=filepath)
        assert not prog.errors_had, f"Errors in {filepath}: {prog.errors_had}"

        # Get JavaScript output - use existing es_ast if already generated,
        # otherwise run EsastGenPass
        if ir.gen.es_ast:
            js_code = es_to_js(ir.gen.es_ast)
        else:
            es_pass = EsastGenPass(ir, prog)
            js_code = es_to_js(es_pass.ir_out.gen.es_ast)
        js_outputs.append(js_code)

        # Get Python output
        py_code = ir.gen.py
        py_outputs.append(py_code)

    # All JavaScript outputs should be identical
    assert js_outputs[0] == js_outputs[1], (
        f"JS output mismatch between mixed_explicit.jac and mixed_cl_default.cl.jac:\n"
        f"--- mixed_explicit.jac ---\n{js_outputs[0]}\n"
        f"--- mixed_cl_default.cl.jac ---\n{js_outputs[1]}"
    )
    assert js_outputs[1] == js_outputs[2], (
        f"JS output mismatch between mixed_cl_default.cl.jac and mixed_sv_default.sv.jac:\n"
        f"--- mixed_cl_default.cl.jac ---\n{js_outputs[1]}\n"
        f"--- mixed_sv_default.sv.jac ---\n{js_outputs[2]}"
    )

    # All Python outputs should be identical
    assert py_outputs[0] == py_outputs[1], (
        f"Python output mismatch between mixed_explicit.jac and mixed_cl_default.cl.jac:\n"
        f"--- mixed_explicit.jac ---\n{py_outputs[0]}\n"
        f"--- mixed_cl_default.cl.jac ---\n{py_outputs[1]}"
    )
    assert py_outputs[1] == py_outputs[2], (
        f"Python output mismatch between mixed_cl_default.cl.jac and mixed_sv_default.sv.jac:\n"
        f"--- mixed_cl_default.cl.jac ---\n{py_outputs[1]}\n"
        f"--- mixed_sv_default.sv.jac ---\n{py_outputs[2]}"
    )

    # Sanity checks - verify both client and server code are present
    assert "client_var" in js_outputs[0], "Client code should be in JavaScript output"
    assert "client_func" in js_outputs[0], (
        "Client function should be in JavaScript output"
    )
    assert "server_var" not in js_outputs[0], (
        "Server code should NOT be in JavaScript output"
    )

    assert "server_var" in py_outputs[0], "Server code should be in Python output"
    assert "server_func" in py_outputs[0], "Server function should be in Python output"
    assert "MyWalker" in py_outputs[0], "Walker should be in Python output"

    # Verify imports are routed to correct outputs
    assert "lodash" in js_outputs[0], "Client import should be in JavaScript output"
    assert "debounce" in js_outputs[0], (
        "Client import symbol should be in JavaScript output"
    )
    assert "lodash" not in py_outputs[0], "Client import should NOT be in Python output"

    assert "from os import path" in py_outputs[0], (
        "Server import should be in Python output"
    )
    assert "os" not in js_outputs[0], "Server import should NOT be in JavaScript output"


def test_reactive_effects_async_entry(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that async can with entry generates useEffect with IIFE wrapper."""
    es_ast = compile_to_esast(fixture_path("reactive_effects.jac"))
    js_code = es_to_js(es_ast)

    # Check that useEffect is imported from @jac/runtime (auto-injected)
    assert 'import { useEffect } from "@jac/runtime"' in js_code, (
        "useEffect should be auto-imported from @jac/runtime"
    )

    # Check that useEffect is called with arrow function
    assert "useEffect(" in js_code, "useEffect should be called"

    # Check that async entry generates IIFE wrapper: (async () => { ... })()
    assert "async () =>" in js_code, "Async entry should generate async arrow function"

    # Check empty dependency array for mount-only effect
    assert "}, [])" in js_code, "Mount effect should have empty dependency array"


def test_reactive_effects_sync_entry(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that non-async can with entry generates useEffect without IIFE."""
    es_ast = compile_to_esast(fixture_path("reactive_effects_sync.jac"))
    js_code = es_to_js(es_ast)

    # Check that useEffect is imported from @jac/runtime (auto-injected)
    assert 'import { useEffect } from "@jac/runtime"' in js_code, (
        "useEffect should be auto-imported from @jac/runtime"
    )

    # Check that useEffect is called
    assert "useEffect(" in js_code, "useEffect should be called"

    # Check that sync entry does NOT wrap in async IIFE
    assert "async () =>" not in js_code, (
        "Sync entry should NOT generate async arrow function"
    )

    # Check empty dependency array for mount-only effect
    assert "}, [])" in js_code, "Mount effect should have empty dependency array"


def test_reactive_effects_cleanup(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that can with exit generates useEffect with cleanup return."""
    es_ast = compile_to_esast(fixture_path("reactive_effects_cleanup.jac"))
    js_code = es_to_js(es_ast)

    # Check that useEffect is imported from @jac/runtime (auto-injected)
    assert 'import { useEffect } from "@jac/runtime"' in js_code, (
        "useEffect should be auto-imported from @jac/runtime"
    )

    # Check that useEffect is called with cleanup return
    assert "useEffect(" in js_code, "useEffect should be called"
    assert "return () =>" in js_code, "Exit effect should return cleanup function"

    # Check empty dependency array
    assert "}, [])" in js_code, "Cleanup effect should have empty dependency array"


def test_reactive_effects_with_dependencies(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that can with (deps) tuple generates useEffect with dependency array."""
    es_ast = compile_to_esast(fixture_path("reactive_effects_deps.jac"))
    js_code = es_to_js(es_ast)

    # Check that useEffect is imported from @jac/runtime (auto-injected)
    assert 'import { useEffect } from "@jac/runtime"' in js_code, (
        "useEffect should be auto-imported from @jac/runtime"
    )

    # Check that useEffect is called
    assert "useEffect(" in js_code, "useEffect should be called"

    # Check that dependency array contains userId and loading (tuple syntax)
    assert "[userId, loading])" in js_code, (
        "Effect with (userId, loading) tuple should have both in dependency array"
    )


def test_jsx_comprehension_basic(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that JSX comprehension generates .map() calls."""
    es_ast = compile_to_esast(fixture_path("jsx_comprehension.jac"))
    js_code = es_to_js(es_ast)

    # Check that basic comprehension generates .map() call
    assert ".map(" in js_code, "JSX comprehension should generate .map() call"
    assert "item =>" in js_code, (
        "JSX comprehension should generate arrow function with item"
    )

    # Check that the JSX element is in the map callback
    assert "__jacJsx" in js_code, "JSX should be lowered to __jacJsx calls"


def test_jsx_comprehension_with_filter(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that JSX comprehension with if clause generates .filter().map() chain."""
    es_ast = compile_to_esast(fixture_path("jsx_comprehension.jac"))
    js_code = es_to_js(es_ast)

    # Check that filtered comprehension generates .filter() call
    assert ".filter(" in js_code, (
        "JSX comprehension with if should generate .filter() call"
    )

    # Check that filter is chained with map
    assert ".filter(" in js_code and ".map(" in js_code, (
        "Filtered JSX comprehension should chain .filter().map()"
    )
