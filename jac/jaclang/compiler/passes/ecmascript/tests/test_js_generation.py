"""Test JavaScript code generation using consolidated Jac fixtures."""

import os
import subprocess
import tempfile
from pathlib import Path

from jaclang.compiler.passes.ecmascript import EsastGenPass
from jaclang.compiler.passes.ecmascript.es_unparse import es_to_js
from jaclang.compiler.program import JacProgram
from jaclang.utils.test import TestCase


class JavaScriptGenerationTests(TestCase):
    """Validate JavaScript generation for core and advanced Jac fixtures."""

    CORE_FIXTURE = "core_language_features.jac"
    ADVANCED_FIXTURE = "advanced_language_features.jac"
    CLIENT_FIXTURE = "client_jsx.jac"

    def get_fixture_path(self, filename: str) -> str:
        """Return absolute path to a fixture file."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        return str(fixtures_dir / filename)

    def compile_fixture_to_js(self, fixture_name: str) -> str:
        """Compile a Jac fixture to JavaScript and return the emitted source."""
        fixture_path = fixture_name
        if not Path(fixture_path).exists():
            fixture_path = self.get_fixture_path(fixture_name)
        prog = JacProgram()
        ir = prog.compile(file_path=fixture_path, no_cgen=True)

        self.assertFalse(
            prog.errors_had,
            f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}",
        )

        es_pass = EsastGenPass(ir, prog)
        es_ir = es_pass.ir_out

        self.assertTrue(hasattr(es_ir.gen, "es_ast"), "es_ast attribute missing")
        self.assertIsNotNone(es_ir.gen.es_ast, "es_ast should not be None")

        return es_to_js(es_ir.gen.es_ast)

    def assert_balanced_syntax(self, js_code: str, fixture_name: str) -> None:
        """Ensure generated JavaScript has balanced delimiters."""
        pairs = [("{", "}"), ("(", ")"), ("[", "]")]
        for open_char, close_char in pairs:
            self.assertEqual(
                js_code.count(open_char),
                js_code.count(close_char),
                f"{fixture_name} produced unbalanced {open_char}{close_char} pairs",
            )

    def assert_no_jac_keywords(self, js_code: str, fixture_name: str) -> None:
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
            self.assertNotIn(
                keyword,
                js_code,
                f"Jac keyword '{keyword.strip()}' leaked into JavaScript for {fixture_name}",
            )

    def test_core_fixture_emits_expected_constructs(self) -> None:
        """Core fixture should cover fundamental language constructs."""
        js_code = self.compile_fixture_to_js(self.CORE_FIXTURE)

        # Functions and control flow
        for pattern in [
            "function add",
            "function greet",
            "function fibonacci",
            "for (const i of range(limit))",
            "while (counter > 0)",
        ]:
            self.assertIn(pattern, js_code)

        # Operators
        for op in ["===", "!==", "&&", "||"]:
            self.assertIn(op, js_code)

        # Classes and enums
        for pattern in [
            "class Person",
            "class Employee extends Person",
            "class Calculator",
            "class MathUtils",
            "const Status",
            "const Priority",
        ]:
            self.assertIn(pattern, js_code)

        # Exception handling
        for pattern in ["try", "catch (err)", "finally"]:
            self.assertIn(pattern, js_code)

        self.assert_balanced_syntax(js_code, self.CORE_FIXTURE)
        self.assert_no_jac_keywords(js_code, self.CORE_FIXTURE)
        self.assertGreater(len(js_code), 200)

    def test_advanced_fixture_emits_expected_constructs(self) -> None:
        """Advanced fixture should exercise higher-level Jac features."""
        js_code = self.compile_fixture_to_js(self.ADVANCED_FIXTURE)

        patterns = [
            "function lambda_examples",
            "async function fetch_value",
            "await fetch_value",
            "async function gather_async",
            "function generator_examples",
            "function spread_and_rest_examples",
            "...defaults",
            "function template_literal_examples",
            'score >= 60 ? "pass" : "fail"',
            "function do_while_simulation",
            "function build_advanced_report",
            "function pattern_matching_examples",
        ]
        for pattern in patterns:
            self.assertIn(pattern, js_code)

        self.assert_balanced_syntax(js_code, self.ADVANCED_FIXTURE)
        self.assert_no_jac_keywords(js_code, self.ADVANCED_FIXTURE)
        self.assertGreater(len(js_code), 150)

    def test_client_fixture_generates_client_bundle(self) -> None:
        """Client-focused fixture should emit JSX-flavoured JavaScript."""
        js_code = self.compile_fixture_to_js(self.CLIENT_FIXTURE)

        for pattern in [
            'const API_URL = "https://api.example.com";',
            "function component()",
            '__jacJsx("div"',
            "class ButtonProps",
            "constructor(props",
        ]:
            self.assertIn(pattern, js_code)
        self.assertNotIn("server_only", js_code)
        self.assert_balanced_syntax(js_code, self.CLIENT_FIXTURE)

    def test_iife_fixture_generates_function_expressions(self) -> None:
        """IIFE-heavy fixture should lower Jac function expressions for JS runtime."""
        fixture_path = self.lang_fixture_abs_path("iife_functions_client.jac")
        js_code = self.compile_fixture_to_js(fixture_path)

        for pattern in [
            "function get_value()",
            "function calculate(x, y)",
            "}();",
            "function outer()",
            "All client-side IIFE tests completed!",
        ]:
            self.assertIn(pattern, js_code)
        self.assertIn(
            "return () => {\n    count = count + 1;\n    return count;\n  };", js_code
        )

    def test_cli_js_command_outputs_js(self) -> None:
        """jac js CLI should emit JavaScript for the core fixture."""
        fixture_path = self.get_fixture_path(self.CORE_FIXTURE)
        env = os.environ.copy()
        project_root = str(Path(__file__).resolve().parents[4])
        existing = env.get("PYTHONPATH", "")
        env["PYTHONPATH"] = f"{project_root}:{existing}" if existing else project_root

        result = subprocess.run(
            ["python3", "-m", "jaclang.cli.cli", "js", fixture_path],
            capture_output=True,
            text=True,
            env=env,
        )

        self.assertEqual(result.returncode, 0, f"CLI failed: {result.stderr}")
        self.assertGreater(len(result.stdout), 0)
        self.assertIn("function add", result.stdout)

    def test_empty_file_generates_minimal_js(self) -> None:
        """Ensure an empty Jac file generates a minimal JavaScript stub."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp:
            tmp.write('"""Empty file for smoke testing."""\n')
            temp_path = tmp.name

        try:
            js_code = self.compile_fixture_to_js(temp_path)
            self.assertLess(len(js_code), 100)
            self.assert_balanced_syntax(js_code, temp_path)
        finally:
            os.unlink(temp_path)

    def test_type_to_typeof_transformation(self) -> None:
        """Test that type() calls transform to typeof operator in JavaScript."""
        jac_code = '''"""Test type() to typeof conversion."""

cl def check_types() {
    let x = 42;
    let y = "hello";
    let obj = {"key": "value"};
    let arr = [1, 2, 3];

    let t1 = type(x);
    let t2 = type(y);
    let t3 = type(obj);
    let t4 = type(arr[0]);

    return t1;
}
'''
        with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp:
            tmp.write(jac_code)
            tmp.flush()
            temp_path = tmp.name

        try:
            js_code = self.compile_fixture_to_js(temp_path)

            for pattern in ["typeof x", "typeof y", "typeof obj", "typeof arr[0]"]:
                self.assertIn(pattern, js_code)
            self.assertNotIn("type(", js_code)
            self.assertEqual(js_code.count("typeof"), 4)
            self.assert_balanced_syntax(js_code, temp_path)
        finally:
            os.unlink(temp_path)

    def test_category1_named_imports_generate_correct_js(self) -> None:
        """Test Category 1 named imports from proposal document."""
        fixture_path = self.get_fixture_path("category1_named_imports.jac")
        js_code = self.compile_fixture_to_js(fixture_path)

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
            self.assertIn(pattern, js_code)

        self.assertIn("function example_usage()", js_code)
        for pattern in ["from react import", "from lodash import"]:
            self.assertNotIn(pattern, js_code)
        self.assert_balanced_syntax(js_code, fixture_path)

    def test_category2_default_imports_generate_correct_js(self) -> None:
        """Test Category 2 default imports from proposal document."""
        fixture_path = self.get_fixture_path("category2_default_imports.jac")
        js_code = self.compile_fixture_to_js(fixture_path)

        imports = [
            'import React from "react";',
            'import axios from "axios";',
            'import Vue from "vue";',
            'import Button from "./components/Button.js";',
            'import utils from "../lib/utils.js";',
        ]
        for pattern in imports:
            self.assertIn(pattern, js_code)

        self.assertIn("function example_usage()", js_code)
        for pattern in ["import { React }", "import { axios }", "import { Vue }"]:
            self.assertNotIn(pattern, js_code)
        self.assert_balanced_syntax(js_code, fixture_path)

    def test_category4_namespace_imports_generate_correct_js(self) -> None:
        """Test Category 4 namespace imports from proposal document."""
        fixture_path = self.get_fixture_path("category4_namespace_imports.jac")
        js_code = self.compile_fixture_to_js(fixture_path)

        imports = [
            'import * as React from "react";',
            'import * as _ from "lodash";',
            'import * as DateUtils from "dateutils";',
            'import * as utils from "./utils.js";',
            'import * as helpers from "../lib/helpers.js";',
        ]
        for pattern in imports:
            self.assertIn(pattern, js_code)

        self.assertIn("function example_usage()", js_code)
        for pattern in ["import { * }", "import { * as"]:
            self.assertNotIn(pattern, js_code)
        self.assert_balanced_syntax(js_code, fixture_path)

    def test_assignment_inside_globvar_js(self) -> None:
        """Test Category 4 namespace imports from proposal document."""
        fixture_path = self.get_fixture_path("js_gen_bug.jac")
        js_code = self.compile_fixture_to_js(fixture_path)
        expected_generated_code = [
            "const setB = item => {",
            "item.b = 90;",
        ]
        for pattern in expected_generated_code:
            self.assertIn(pattern, js_code)

    def test_hyphenated_package_imports_generate_correct_js(self) -> None:
        """Test string literal imports for hyphenated package names."""
        fixture_path = self.get_fixture_path("hyphenated_imports.jac")
        js_code = self.compile_fixture_to_js(fixture_path)

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
            self.assertIn(pattern, js_code)

        self.assertIn("function TestComponent()", js_code)
        for pattern in ["from react-dom import", "from 'react-dom' import"]:
            self.assertNotIn(pattern, js_code)
        self.assert_balanced_syntax(js_code, fixture_path)

    def test_relative_imports_include_js_extension(self) -> None:
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
    let formatter = MessageFormatter();
    return formatter.format("test");
}
}
'''
        with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp:
            tmp.write(jac_code)
            tmp.flush()
            temp_path = tmp.name

        try:
            js_code = self.compile_fixture_to_js(temp_path)

            imports = [
                'import { MessageFormatter } from "./utils.js";',
                'import { formatter } from "../lib.js";',
                'import { settings } from "../../config.js";',
                'import { Button } from "./components/Button.js";',
            ]
            for pattern in imports:
                self.assertIn(pattern, js_code)

            self.assertIn("function test_usage()", js_code)

            # Verify all relative imports have .js extension
            import_lines = [
                line
                for line in js_code.split("\n")
                if "import" in line and "from" in line
            ]
            relative_imports = [
                line for line in import_lines if "./" in line or "../" in line
            ]
            for line in relative_imports:
                self.assertTrue(
                    '.js"' in line or ".js'" in line,
                    f"Relative import missing .js: {line}",
                )

            self.assert_balanced_syntax(js_code, temp_path)
        finally:
            os.unlink(temp_path)

    def test_side_effect_imports_generate_correct_js(self) -> None:
        """Test that side effect imports generate correct JavaScript import statements."""
        fixture_path = self.get_fixture_path("side_effect_imports.jac")
        js_code = self.compile_fixture_to_js(fixture_path)

        imports = [
            'import "mytest/side_effects";',
            'import "./styles/side_effects.css";',
            'import "bootstrap/dist/css/bootstrap.min.css";',
        ]
        for pattern in imports:
            self.assertIn(pattern, js_code)

        self.assert_balanced_syntax(js_code, fixture_path)

    def test_fstring_simple_variable_interpolation(self) -> None:
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
            js_code = self.compile_fixture_to_js(temp_path)

            self.assertIn("function greet_user", js_code)
            self.assertIn("`", js_code)
            for pattern in ["${name}", "${age}", "Hello,", "You are", "years old."]:
                self.assertIn(pattern, js_code)
            self.assertIn("`Hello, ${name}! You are ${age} years old.`", js_code)
            self.assert_balanced_syntax(js_code, temp_path)
        finally:
            os.unlink(temp_path)

    def test_fstring_with_expressions(self) -> None:
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
            js_code = self.compile_fixture_to_js(temp_path)

            for pattern in [
                "function calculate_message",
                "function conditional_message",
            ]:
                self.assertIn(pattern, js_code)

            for pattern in [
                "`",
                "${x}",
                "${y}",
                "${x + y}",
                "${score}",
                "${score >= 60}",
                "The sum of",
                "and",
                "is",
                "Score:",
                "Status:",
            ]:
                self.assertIn(pattern, js_code)

            self.assert_balanced_syntax(js_code, temp_path)
        finally:
            os.unlink(temp_path)

    def test_fstring_advanced_fixture_template_literals(self) -> None:
        """Test that the advanced fixture's f-strings generate proper template literals."""
        js_code = self.compile_fixture_to_js(self.ADVANCED_FIXTURE)

        self.assertIn("function template_literal_examples", js_code)
        self.assertGreaterEqual(js_code.count("`"), 2)
        for pattern in [
            "${",
            "${user}",
            "${score}",
            "${status}",
            "scored",
            "which is a",
        ]:
            self.assertIn(pattern, js_code)

    def test_fstring_edge_cases(self) -> None:
        """Test f-string edge cases: empty, text-only, expression-only."""
        jac_code = '''"""Test f-string edge cases."""

cl def test_edge_cases() -> dict {
    let name = "Alice";
    let value = 42;

    # Text only (no interpolation)
    let text_only = f"This is just plain text";

    # Expression only (no static text)
    let expr_only = f"{value}";

    # Multiple consecutive expressions
    let consecutive = f"{name}{value}";

    # Mixed with spaces
    let mixed = f"Name: {name}, Value: {value}";

    return {"text": text_only, "expr": expr_only, "cons": consecutive, "mixed": mixed};
}
'''
        with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp:
            tmp.write(jac_code)
            tmp.flush()
            temp_path = tmp.name

        try:
            js_code = self.compile_fixture_to_js(temp_path)

            self.assertIn("function test_edge_cases", js_code)
            for pattern in [
                "`This is just plain text`",
                "`${value}`",
                "`${name}${value}`",
                "Name:",
                "Value:",
                "${name}",
                "${value}",
            ]:
                self.assertIn(pattern, js_code)
            self.assert_balanced_syntax(js_code, temp_path)
        finally:
            os.unlink(temp_path)

    def test_fstring_no_concatenation_operators(self) -> None:
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
            js_code = self.compile_fixture_to_js(temp_path)

            for pattern in ["`", "${user}", "${count}"]:
                self.assertIn(pattern, js_code)

            # Verify return uses template literal, not concatenation
            return_statements = [
                line for line in js_code.split("\n") if "return" in line
            ]
            fstring_returns = [line for line in return_statements if "${" in line]
            for ret_line in fstring_returns:
                self.assertEqual(
                    ret_line.count("`"),
                    2,
                    f"Expected single template literal: {ret_line}",
                )

            self.assert_balanced_syntax(js_code, temp_path)
        finally:
            os.unlink(temp_path)
