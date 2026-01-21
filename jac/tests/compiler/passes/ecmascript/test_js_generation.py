"""Test JavaScript code generation using consolidated Jac fixtures."""

import os
import subprocess
import tempfile
from collections.abc import Callable
from pathlib import Path

import pytest

from jaclang.compiler.passes.ecmascript import EsastGenPass
from jaclang.compiler.passes.ecmascript.es_unparse import es_to_js
from jaclang.compiler.passes.ecmascript.estree import Node as EsNode
from jaclang.pycore.program import JacProgram


@pytest.fixture
def fixture_path() -> Callable[[str], str]:
    """Return a function that returns absolute path to a fixture file."""

    def _get_fixture_path(filename: str) -> str:
        fixtures_dir = Path(__file__).parent / "fixtures"
        return str(fixtures_dir / filename)

    return _get_fixture_path


@pytest.fixture
def lang_fixture_path() -> Callable[[str], str]:
    """Return a function that returns absolute path to a language fixture file."""
    from pathlib import Path

    def _get_lang_fixture_path(file: str) -> str:
        # tests/compiler/passes/ecmascript/ -> tests/language/fixtures/
        tests_dir = Path(__file__).parent.parent.parent.parent
        file_path = tests_dir / "language" / "fixtures" / file
        return str(file_path.resolve())

    return _get_lang_fixture_path


def compile_fixture_to_js(
    fixture_name: str, fixture_path_func: Callable[[str], str] | None = None
) -> str:
    """Compile a Jac fixture to JavaScript and return the emitted source."""
    fixture_path = fixture_name
    if not Path(fixture_path).exists() and fixture_path_func:
        fixture_path = fixture_path_func(fixture_name)
    prog = JacProgram()
    ir = prog.compile(file_path=fixture_path, no_cgen=True)

    assert not prog.errors_had, (
        f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    )

    es_pass = EsastGenPass(ir, prog)
    es_ir = es_pass.ir_out

    assert hasattr(es_ir.gen, "es_ast"), "es_ast attribute missing"
    es_ast = es_ir.gen.es_ast
    assert isinstance(es_ast, EsNode), "es_ast should be an EsNode"

    return es_to_js(es_ast)


def assert_balanced_syntax(js_code: str, fixture_name: str) -> None:
    """Ensure generated JavaScript has balanced delimiters."""
    pairs = [("{", "}"), ("(", ")"), ("[", "]")]
    for open_char, close_char in pairs:
        assert js_code.count(open_char) == js_code.count(close_char), (
            f"{fixture_name} produced unbalanced {open_char}{close_char} pairs"
        )


def assert_no_jac_keywords(js_code: str, fixture_name: str) -> None:
    """Verify Jac-specific keywords are absent from generated JavaScript."""
    jac_keywords = [
        "can ",
        "has ",
        "obj ",
        "walker ",
        "node ",
        "edge ",
        "visit ",
        "spawn ",
        "disengage ",
        "here ",
        "root ",
    ]

    for keyword in jac_keywords:
        assert keyword not in js_code, (
            f"Jac keyword '{keyword.strip()}' leaked into JavaScript for {fixture_name}"
        )


def test_core_fixture_emits_expected_constructs(
    fixture_path: Callable[[str], str],
) -> None:
    """Core fixture should cover fundamental language constructs."""
    core_fixture = "core_language_features.jac"
    js_code = compile_fixture_to_js(core_fixture, fixture_path)

    # Functions and control flow
    for pattern in [
        "function add",
        "function greet",
        "function fibonacci",
        "for (const i of array)",
        "for (let i = 0; (i < limit); i += 1)",
        "while ((counter > 0))",
    ]:
        assert pattern in js_code

    # Expressions with parentheses
    for expr in ["(items.length + 1)", "(Math.round((divided * 10)) / 10)"]:
        assert expr in js_code

    # Operators
    for op in ["===", "!==", "&&", "||"]:
        assert op in js_code

    # Switch Statement
    assert "switch (fruit)" in js_code
    for case in ['case "apple":', 'case "banana":', "default:"]:
        assert case in js_code

    # Classes and enums
    for pattern in [
        "class Person",
        "class Employee extends Person",
        "class Calculator",
        "class MathUtils",
        "const Status",
        "const Priority",
    ]:
        assert pattern in js_code

    # Exception handling
    for pattern in ["try", "catch (err)", "finally"]:
        assert pattern in js_code

    # Support strings within jsx
    assert '"\\"Authentication\\" App"' in js_code

    assert_balanced_syntax(js_code, core_fixture)
    assert_no_jac_keywords(js_code, core_fixture)
    assert len(js_code) > 200


def test_advanced_fixture_emits_expected_constructs(
    fixture_path: Callable[[str], str],
) -> None:
    """Advanced fixture should exercise higher-level Jac features."""
    advanced_fixture = "advanced_language_features.jac"
    js_code = compile_fixture_to_js(advanced_fixture, fixture_path)

    patterns = [
        "function lambda_examples",
        "async function fetch_value",
        "await fetch_value",
        "async function gather_async",
        "function generator_examples",
        "function spread_and_rest_examples",
        "...defaults",
        "function template_literal_examples",
        '((score >= 60) ? "pass" : "fail")',
        "function do_while_simulation",
        "function build_advanced_report",
        "function pattern_matching_examples",
    ]
    for pattern in patterns:
        assert pattern in js_code

    # check props transformation
    assert "function TodoList(props) {" in js_code
    assert "const {filteredTodos, toggleTodo, deleteTodo} = props;" in js_code
    assert (
        '"toggleTodo": toggleTodo, "deleteTodo": props.deleteTodo, "children": props.children'
        in js_code
    )

    assert "function PropTodoList(props) {" in js_code
    assert "const {filteredTodos, toggleTodo, deleteTodo} = props;" in js_code
    assert (
        '"toggleTodo": props.toggleTodo, "deleteTodo": props.deleteTodo, "children": props.children}, []);'
        in js_code
    )

    assert_balanced_syntax(js_code, advanced_fixture)
    assert_no_jac_keywords(js_code, advanced_fixture)
    assert len(js_code) > 150


def test_client_fixture_generates_client_bundle(
    fixture_path: Callable[[str], str],
) -> None:
    """Client-focused fixture should emit JSX-flavoured JavaScript."""
    client_fixture = "client_jsx.jac"
    js_code = compile_fixture_to_js(client_fixture, fixture_path)

    for pattern in [
        'let API_URL = "https://api.example.com";',
        "function component()",
        '__jacJsx("div"',
        "class ButtonProps",
        "constructor(props",
    ]:
        assert pattern in js_code
    assert "server_only" not in js_code
    assert_balanced_syntax(js_code, client_fixture)


def test_iife_fixture_generates_function_expressions(
    lang_fixture_path: Callable[[str], str],
) -> None:
    """IIFE-heavy fixture should lower Jac function expressions for JS runtime."""
    fixture_path = lang_fixture_path("iife_functions_client.jac")
    js_code = compile_fixture_to_js(fixture_path)

    for pattern in [
        "function get_value()",
        "function calculate(x, y)",
        "}();",
        "function outer()",
        "All client-side IIFE tests completed!",
    ]:
        assert pattern in js_code
    assert (
        "return () => {\n    count = (count + 1);\n    return count;\n  };" in js_code
    )


def test_cli_js_command_outputs_js(fixture_path: Callable[[str], str]) -> None:
    """jac js CLI should emit JavaScript for the core fixture."""
    core_fixture = "core_language_features.jac"
    fixture_file_path = fixture_path(core_fixture)
    env = os.environ.copy()
    project_root = str(Path(__file__).resolve().parents[4])
    existing = env.get("PYTHONPATH", "")
    env["PYTHONPATH"] = f"{project_root}:{existing}" if existing else project_root

    result = subprocess.run(
        ["python3", "-m", "jaclang.cli.cli", "js", fixture_file_path],
        capture_output=True,
        text=True,
        env=env,
    )

    assert result.returncode == 0, f"CLI failed: {result.stderr}"
    assert len(result.stdout) > 0
    assert "function add" in result.stdout


def test_cl_only_js_command_outputs_js(
    fixture_path: Callable[[str], str],
) -> None:
    """jac js CLI with cl only file should emit JavaScript."""
    core_fixture = "cl_only.cl.jac"
    fixture_file_path = fixture_path(core_fixture)
    env = os.environ.copy()
    project_root = str(Path(__file__).resolve().parents[4])
    existing = env.get("PYTHONPATH", "")
    env["PYTHONPATH"] = f"{project_root}:{existing}" if existing else project_root

    result = subprocess.run(
        [
            "python3",
            "-m",
            "jaclang.cli.cli",
            "js",
            fixture_file_path,
        ],
        capture_output=True,
        text=True,
        env=env,
    )

    assert result.returncode == 0, (
        f"CLI failed to compile cl only file: {result.stderr}"
    )
    assert len(result.stdout) > 0
    assert "function greet(name) {" in result.stdout


def test_empty_file_generates_minimal_js() -> None:
    """Ensure an empty Jac file generates a minimal JavaScript stub."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp:
        tmp.write('"""Empty file for smoke testing."""\n')
        temp_path = tmp.name

    try:
        js_code = compile_fixture_to_js(temp_path)
        assert len(js_code) < 100
        assert_balanced_syntax(js_code, temp_path)
    finally:
        os.unlink(temp_path)


def test_type_to_typeof_transformation() -> None:
    """Test that type() calls transform to typeof operator in JavaScript."""
    jac_code = '''"""Test type() to typeof conversion."""

cl def check_types() {
    x = 42;
    y = "hello";
    my_obj = {"key": "value"};
    arr = [1, 2, 3];

    t1 = type(x);
    t2 = type(y);
    t3 = type(my_obj);
    t4 = type(arr[0]);

    return t1;
}
'''
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp:
        tmp.write(jac_code)
        tmp.flush()
        temp_path = tmp.name

    try:
        js_code = compile_fixture_to_js(temp_path)

        for pattern in ["typeof x", "typeof y", "typeof my_obj", "typeof arr[0]"]:
            assert pattern in js_code
        assert "type(" not in js_code
        assert js_code.count("typeof") == 4
        assert_balanced_syntax(js_code, temp_path)
    finally:
        os.unlink(temp_path)


def test_category1_named_imports_generate_correct_js(
    fixture_path: Callable[[str], str],
) -> None:
    """Test Category 1 named imports from proposal document."""
    fixture_file_path = fixture_path("category1_named_imports.jac")
    js_code = compile_fixture_to_js(fixture_file_path)

    imports = [
        'import { useState } from "react";',
        'import { map, filter, reduce } from "lodash";',
        'import { get as httpGet } from "axios";',
        'import { createApp, ref as reactive, computed } from "vue";',
        'import { helper } from "./utils.js";',
        'import { formatter as format } from "../lib.js";',
        'import { settings } from "../../config.js";',
        'import { renderJsxTree, jacLogin, jacLogout } from "client_runtime";',
    ]
    for pattern in imports:
        assert pattern in js_code

    assert "function example_usage()" in js_code
    for pattern in ["from react import", "from lodash import"]:
        assert pattern not in js_code
    assert_balanced_syntax(js_code, fixture_file_path)


def test_category2_default_imports_generate_correct_js(
    fixture_path: Callable[[str], str],
) -> None:
    """Test Category 2 default imports from proposal document."""
    fixture_file_path = fixture_path("category2_default_imports.jac")
    js_code = compile_fixture_to_js(fixture_file_path)

    imports = [
        'import React from "react";',
        'import axios from "axios";',
        'import Vue from "vue";',
        'import Button from "./components/Button.js";',
        'import utils from "../lib/utils.js";',
    ]
    for pattern in imports:
        assert pattern in js_code

    assert "function example_usage()" in js_code
    for pattern in ["import { React }", "import { axios }", "import { Vue }"]:
        assert pattern not in js_code
    assert_balanced_syntax(js_code, fixture_file_path)


def test_category4_namespace_imports_generate_correct_js(
    fixture_path: Callable[[str], str],
) -> None:
    """Test Category 4 namespace imports from proposal document."""
    fixture_file_path = fixture_path("category4_namespace_imports.jac")
    js_code = compile_fixture_to_js(fixture_file_path)

    imports = [
        'import * as React from "react";',
        'import * as _ from "lodash";',
        'import * as DateUtils from "dateutils";',
        'import * as utils from "./utils.js";',
        'import * as helpers from "../lib/helpers.js";',
    ]
    for pattern in imports:
        assert pattern in js_code

    assert "function example_usage()" in js_code
    for pattern in ["import { * }", "import { * as"]:
        assert pattern not in js_code
    assert_balanced_syntax(js_code, fixture_file_path)


def test_atom_trailer_starts_with_specialvaref_js(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that atom trailers starting with SpecialVarRef generate correct JS."""
    fixture_file_path = fixture_path("root_render.jac")
    js_code = compile_fixture_to_js(fixture_file_path)

    assert "root.render();" in js_code
    assert "obj" not in js_code


def test_assignment_inside_globvar_js(fixture_path: Callable[[str], str]) -> None:
    """Test Category 4 namespace imports from proposal document."""
    fixture_file_path = fixture_path("js_gen_bug.jac")
    js_code = compile_fixture_to_js(fixture_file_path)
    expected_generated_code = [
        "let setB = item => {",
        "item.b = 90;",
    ]
    for pattern in expected_generated_code:
        assert pattern in js_code


def test_hyphenated_package_imports_generate_correct_js(
    fixture_path: Callable[[str], str],
) -> None:
    """Test string literal imports for hyphenated package names."""
    fixture_file_path = fixture_path("hyphenated_imports.jac")
    js_code = compile_fixture_to_js(fixture_file_path)

    imports = [
        'import { render, hydrate } from "react-dom";',
        'import { render as renderDOM } from "react-dom";',
        'import * as ReactDOM from "react-dom";',
        'import ReactDOMDefault from "react-dom";',
        'import RD, { createPortal } from "react-dom";',
        'import styled from "styled-components";',
        'import { format, parse, addDays } from "date-fns";',
        'import { BrowserRouter, Route, Link } from "react-router-dom";',
        'import { useState, useEffect } from "react";',
        'import { map, filter } from "lodash";',
    ]
    for pattern in imports:
        assert pattern in js_code

    assert "function TestComponent()" in js_code
    for pattern in ["from react-dom import", "from 'react-dom' import"]:
        assert pattern not in js_code
    assert_balanced_syntax(js_code, fixture_file_path)


def test_relative_imports_include_js_extension() -> None:
    """Test that relative imports generate .js extensions for browser compatibility."""
    jac_code = '''"""Test relative imports with .js extension."""

cl {
# Single dot relative import
import from .utils { MessageFormatter }

# Double dot relative import
import from ..lib { formatter }

# Triple dot relative import
import from ...config { settings }

# Module name with dots (should still get .js)
import from .components.Button { Button }

# Using imported functions
def test_usage() {
    fmt = MessageFormatter();
    return fmt.format("test");
}
}
'''
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp:
        tmp.write(jac_code)
        tmp.flush()
        temp_path = tmp.name

    try:
        js_code = compile_fixture_to_js(temp_path)

        imports = [
            'import { MessageFormatter } from "./utils.js";',
            'import { formatter } from "../lib.js";',
            'import { settings } from "../../config.js";',
            'import { Button } from "./components/Button.js";',
        ]
        for pattern in imports:
            assert pattern in js_code

        assert "function test_usage()" in js_code

        # Verify all relative imports have .js extension
        import_lines = [
            line for line in js_code.split("\n") if "import" in line and "from" in line
        ]
        relative_imports = [
            line for line in import_lines if "./" in line or "../" in line
        ]
        for line in relative_imports:
            assert '.js"' in line or ".js'" in line, (
                f"Relative import missing .js: {line}"
            )

        assert_balanced_syntax(js_code, temp_path)
    finally:
        os.unlink(temp_path)


def test_side_effect_imports_generate_correct_js(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that side effect imports generate correct JavaScript import statements."""
    fixture_file_path = fixture_path("side_effect_imports.jac")
    js_code = compile_fixture_to_js(fixture_file_path)

    imports = [
        'import "mytest/side_effects";',
        'import "./styles/side_effects.css";',
        'import "bootstrap/dist/css/bootstrap.min.css";',
    ]
    for pattern in imports:
        assert pattern in js_code

    assert_balanced_syntax(js_code, fixture_file_path)


def test_fstring_simple_variable_interpolation() -> None:
    """Test that f-strings with simple variable interpolation generate correct template literals."""
    jac_code = '''"""Test f-string with simple variables."""

cl def greet_user(name: str, age: int) -> str {
    return f"Hello, {name}! You are {age} years old.";
}
'''
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp:
        tmp.write(jac_code)
        tmp.flush()
        temp_path = tmp.name

    try:
        js_code = compile_fixture_to_js(temp_path)

        assert "function greet_user" in js_code
        assert "`" in js_code
        for pattern in ["${name}", "${age}", "Hello,", "You are", "years old."]:
            assert pattern in js_code
        assert "`Hello, ${name}! You are ${age} years old.`" in js_code
        assert_balanced_syntax(js_code, temp_path)
    finally:
        os.unlink(temp_path)


def test_fstring_with_expressions() -> None:
    """Test that f-strings with expressions generate correct template literals."""
    jac_code = '''"""Test f-string with expressions."""

cl def calculate_message(x: int, y: int) -> str {
    return f"The sum of {x} and {y} is {x + y}";
}

cl def conditional_message(score: int) -> str {
    return f"Score: {score}, Status: {score >= 60}";
}
'''
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp:
        tmp.write(jac_code)
        tmp.flush()
        temp_path = tmp.name

    try:
        js_code = compile_fixture_to_js(temp_path)

        for pattern in [
            "function calculate_message",
            "function conditional_message",
        ]:
            assert pattern in js_code

        for pattern in [
            "`",
            "${x}",
            "${y}",
            "${(x + y)}",
            "${score}",
            "${(score >= 60)}",
            "The sum of",
            "and",
            "is",
            "Score:",
            "Status:",
        ]:
            assert pattern in js_code

        assert_balanced_syntax(js_code, temp_path)
    finally:
        os.unlink(temp_path)


def test_fstring_advanced_fixture_template_literals(
    fixture_path: Callable[[str], str],
) -> None:
    """Test that the advanced fixture's f-strings generate proper template literals."""
    advanced_fixture = "advanced_language_features.jac"
    js_code = compile_fixture_to_js(advanced_fixture, fixture_path)

    assert "function template_literal_examples" in js_code
    assert js_code.count("`") >= 2
    for pattern in [
        "${",
        "${user}",
        "${score}",
        "${status}",
        "scored",
        "which is a",
    ]:
        assert pattern in js_code


def test_fstring_edge_cases() -> None:
    """Test f-string edge cases: empty, text-only, expression-only."""
    jac_code = '''"""Test f-string edge cases."""

cl def test_edge_cases() -> dict {
    name = "Alice";
    value = 42;

    # Text only (no interpolation)
    text_only = f"This is just plain text";

    # Expression only (no static text)
    expr_only = f"{value}";

    # Multiple consecutive expressions
    consecutive = f"{name}{value}";

    # Mixed with spaces
    mixed = f"Name: {name}, Value: {value}";

    return {"text": text_only, "expr": expr_only, "cons": consecutive, "mixed": mixed};
}
'''
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp:
        tmp.write(jac_code)
        tmp.flush()
        temp_path = tmp.name

    try:
        js_code = compile_fixture_to_js(temp_path)

        assert "function test_edge_cases" in js_code
        for pattern in [
            "`This is just plain text`",
            "`${value}`",
            "`${name}${value}`",
            "Name:",
            "Value:",
            "${name}",
            "${value}",
        ]:
            assert pattern in js_code
        assert_balanced_syntax(js_code, temp_path)
    finally:
        os.unlink(temp_path)


def test_fstring_no_concatenation_operators() -> None:
    """Test that f-strings don't generate string concatenation with + operators."""
    jac_code = '''"""Test that f-strings use template literals, not concatenation."""

cl def format_message(user: str, count: int) -> str {
    return f"User {user} has {count} items";
}
'''
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp:
        tmp.write(jac_code)
        tmp.flush()
        temp_path = tmp.name

    try:
        js_code = compile_fixture_to_js(temp_path)

        for pattern in ["`", "${user}", "${count}"]:
            assert pattern in js_code

        # Verify return uses template literal, not concatenation
        return_statements = [line for line in js_code.split("\n") if "return" in line]
        fstring_returns = [line for line in return_statements if "${" in line]
        for ret_line in fstring_returns:
            assert ret_line.count("`") == 2, (
                f"Expected single template literal: {ret_line}"
            )

        assert_balanced_syntax(js_code, temp_path)
    finally:
        os.unlink(temp_path)


def test_keyword_variables(fixture_path: Callable[[str], str]) -> None:
    """Test that the advanced fixture's f-strings generate proper template literals."""
    advanced_fixture = "advanced_language_features.jac"
    js_code = compile_fixture_to_js(advanced_fixture, fixture_path)

    assert "function def(from, class) {" in js_code
    for pattern in [
        'print("From is:", from);',
        'print("Class is:", class);',
    ]:
        assert pattern in js_code


def test_separated_files(fixture_path: Callable[[str], str]) -> None:
    """Test features functionality with separated files.

    With .cl.jac files as standalone modules, we compile the client file directly.
    """
    # Compile the standalone client module directly
    client_fixture = "separated_client.cl.jac"
    js_code = compile_fixture_to_js(client_fixture, fixture_path)

    # Check the spawned walker function is present
    assert "let response = await __jacSpawn(" in js_code
    assert '__jacSpawn("create_todo", "", {"text": input.trim()});' in js_code
