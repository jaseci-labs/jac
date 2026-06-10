"""Test JavaScript code generation using consolidated Jac fixtures.

Migrated from test_js_generation.py to native Jac test format.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.estree { Node as EsNode }
import from jaclang.jac0core.modresolver { convert_to_js_import_path }
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     ),
     LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures"),
     _js_compile_cache: dict[str, str] = {},
     _test_tmp_dir: str = tempfile.mkdtemp(prefix="jac_test_js_");

"""Write code to a temp .jac file in a dedicated directory (avoids /tmp scan)."""
def write_temp_jac(code: str) -> str {
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as tmp {
        tmp.write(code);
        return tmp.name;
    }
}

"""Compile a Jac fixture to JavaScript and return the emitted source."""
def compile_fixture_to_js(fixture_name: str, fixture_dir: str = "") -> str {
    fixture_path = fixture_name;
    if not Path(fixture_path).exists() and fixture_dir {
        fixture_path = os.path.join(fixture_dir, fixture_name);
    }
    cache_key = os.path.abspath(fixture_path);
    if cache_key in _js_compile_cache {
        return _js_compile_cache[cache_key];
    }
    prog = JacProgram();
    ir = prog.compile(file_path=fixture_path, no_cgen=True, type_check=True);

    # Filter out type-checker diagnostics (non-fatal warnings about
    # Unknown types in client code).  Only fail on parse/compile errors.
    import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
    _fatal = [
        e
        for e in prog.errors_had
        if e.from_pass is not TypeCheckPass
    ];
    assert not _fatal , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in _fatal]}"
    );

    es_pass = EsastGenPass(ir_in=ir, prog=prog);
    es_ir = es_pass.ir_out;

    assert hasattr(es_ir.gen, "es_ast") , "es_ast attribute missing";
    es_ast = es_ir.gen.es_ast;
    assert isinstance(es_ast, EsNode) , "es_ast should be an EsNode";

    result = es_to_js(es_ast);
    _js_compile_cache[cache_key] = result;
    return result;
}

"""Compile a fixture through the normal production codegen path."""
def compile_fixture_to_js_production(fixture_name: str, fixture_dir: str = "") -> str {
    fixture_path = fixture_name;
    if not Path(fixture_path).exists() and fixture_dir {
        fixture_path = os.path.join(fixture_dir, fixture_name);
    }
    prog = JacProgram();
    ir = prog.compile(file_path=fixture_path);
    assert not prog.errors_had , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.js and ir.gen.js.strip() , (
        f"Production JS codegen produced no output for {fixture_name}"
    );
    return ir.gen.js;
}

"""Ensure generated JavaScript has balanced delimiters."""
def assert_balanced_syntax(js_code: str, fixture_name: str) {
    pairs = [("{", "}"), ("(", ")"), ("[", "]")];
    for (open_char, close_char) in pairs {
        assert js_code.count(open_char) == js_code.count(close_char) , (
            f"{fixture_name} produced unbalanced {open_char}{close_char} pairs"
        );
    }
}

"""Verify Jac-specific keywords are absent from generated JavaScript.

Uses regex word-boundary matching so that Jac keywords appearing as
JS variable names (e.g. ``let has = false;`` inside the _jac runtime)
do not trigger false positives.
"""
def assert_no_jac_keywords(js_code: str, fixture_name: str) {
    import re;

    # Strip string literals so English words inside error messages
    # and other quoted text don't trigger false positives.
    code_without_strings = re.sub(r'"(?:[^"\\]|\\.)*"', '""', js_code);
    code_without_strings = re.sub(r"'(?:[^'\\]|\\.)*'", "''", code_without_strings);
    code_without_strings = re.sub(r"`(?:[^`\\]|\\.)*`", "``", code_without_strings);

    # Each entry: (keyword, pattern that matches Jac *statement* usage)
    # e.g. ``has varname`` at the start of a statement, not ``let has = ...``
    jac_keywords = [
        ("can", r"(?<![.\w])can\s+\w+\s*[\({]"),
        ("has", r"(?<![.\w])has\s+\w+\s*[:=;]"),
        ("obj", r"(?<![.\w])obj\s+\w+"),
        ("walker", r"(?<![.\w])walker\s+\w+"),
        ("node", r"(?<![.\w])node\s+\w+"),
        ("edge", r"(?<![.\w])edge\s+\w+"),
        ("visit", r"(?<![.\w])visit\s"),
        ("spawn", r"(?<![.\w])spawn\s"),
        ("disengage", r"(?<![.\w])disengage\b"),
        ("here", r"(?<![.\w])here\b"),

    ];

    for (kw_name, pattern) in jac_keywords {
        assert not re.search(pattern, code_without_strings) , (
            f"Jac keyword '{kw_name}' leaked into JavaScript for {fixture_name}"
        );
    }
}

test "core fixture emits expected constructs" {
    core_fixture = "core_language_features.jac";
    js_code = compile_fixture_to_js(core_fixture, FIXTURES);

    # Functions and control flow
    for pattern in [
        "function add",
        "function greet",
        "function fibonacci",
        "for (const i of array)",
        "for (let i = 0; (i < limit); i += 1)",
        "while ((counter > 0))",

    ] {
        assert pattern in js_code;
    }

    # Expressions with parentheses
    for expr in ["(items.length + 1)", "(Math.round((divided * 10)) / 10)"] {
        assert expr in js_code;
    }

    # Operators
    for op in ["===", "!==", "&&", "||"] {
        assert op in js_code;
    }

    # Switch Statement
    assert "switch (fruit)" in js_code;
    for case_str in ["case \"apple\":", "case \"banana\":", "default:"] {
        assert case_str in js_code;
    }

    # Classes and enums
    for pattern in [
        "class Person",
        "class Employee extends Person",
        "class Calculator",
        "class MathUtils",
        "const Status",
        "const Priority",

    ] {
        assert pattern in js_code;
    }

    # Exception handling
    for pattern in ["try", "catch (__jac_e)", "finally"] {
        assert pattern in js_code;
    }

    # Support strings within jsx (quotes in JSX text must be escaped)
    assert "\\\"Authentication\\\" App" in js_code;

    assert_balanced_syntax(js_code, core_fixture);
    assert_no_jac_keywords(js_code, core_fixture);
    assert len(js_code) > 200;
}

test "advanced fixture emits expected constructs" {
    advanced_fixture = "advanced_language_features.jac";
    js_code = compile_fixture_to_js(advanced_fixture, FIXTURES);

    patterns = [
        "function lambda_examples",
        "async function fetch_value",
        "await fetch_value",
        "async function gather_async",
        "function generator_examples",
        "function spread_and_rest_examples",
        "...defaults",
        "function template_literal_examples",
        "((score >= 60) ? \"pass\" : \"fail\")",
        "function do_while_simulation",
        "function build_advanced_report",
        "function pattern_matching_examples",

    ];
    for pattern in patterns {
        assert pattern in js_code;
    }

    # check props transformation
    assert "function TodoList(props) {" in js_code;
    assert "const {filteredTodos, toggleTodo, deleteTodo} = props;" in js_code;
    assert (
        "\"toggleTodo\": toggleTodo, \"deleteTodo\": props.deleteTodo, \"children\": props.children" in js_code
    );

    assert "function PropTodoList(props) {" in js_code;
    assert "const {filteredTodos, toggleTodo, deleteTodo} = props;" in js_code;
    assert (
        "\"toggleTodo\": props.toggleTodo, \"deleteTodo\": props.deleteTodo, \"children\": props.children}, []);" in js_code
    );

    assert_balanced_syntax(js_code, advanced_fixture);
    assert_no_jac_keywords(js_code, advanced_fixture);
    assert len(js_code) > 150;
}

test "client fixture generates client bundle" {
    client_fixture = "client_jsx.jac";
    js_code = compile_fixture_to_js(client_fixture, FIXTURES);

    for pattern in [
        "let API_URL = \"https://api.example.com\";",
        "function component()",
        "__jacJsx(\"div\"",
        "class ButtonProps",
        "constructor(props",

    ] {
        assert pattern in js_code;
    }
    assert "server_only" not in js_code;
    assert_balanced_syntax(js_code, client_fixture);
}

test "iife fixture generates function expressions" {
    fp = os.path.join(LANG_FIXTURES, "iife_functions_client.jac");
    js_code = compile_fixture_to_js(fp);

    for pattern in [
        "function get_value()",
        "function calculate(x, y)",
        "})();",
        "function outer()",
        "All client-side IIFE tests completed!",

    ] {
        assert pattern in js_code;
    }
    assert (
        "return () => {\n    count = (count + 1);\n    return count;\n  };" in js_code
    );
}

test "cli js command outputs js" {
    core_fixture = "core_language_features.jac";
    fixture_file_path = os.path.join(FIXTURES, core_fixture);
    env = os.environ.copy();
    project_root = JAC_ROOT;
    existing = env.get("PYTHONPATH", "");
    env["PYTHONPATH"] = f"{project_root}:{existing}" if existing else project_root;

    result = subprocess.run(
        [sys.executable, "-m", "jaclang.cli.cli", "js", fixture_file_path],
        capture_output=True,
        text=True,
        env=env,
    );

    assert result.returncode == 0 , f"CLI failed: {result.stderr}";
    assert len(result.stdout) > 0;
    assert "function add" in result.stdout;
}

test "cl only js command outputs js" {
    core_fixture = "cl_only.cl.jac";
    fixture_file_path = os.path.join(FIXTURES, core_fixture);
    env = os.environ.copy();
    project_root = JAC_ROOT;
    existing = env.get("PYTHONPATH", "");
    env["PYTHONPATH"] = f"{project_root}:{existing}" if existing else project_root;

    result = subprocess.run(
        [sys.executable, "-m", "jaclang.cli.cli", "js", fixture_file_path, ],
        capture_output=True,
        text=True,
        env=env,
    );

    assert result.returncode == 0 , (
        f"CLI failed to compile cl only file: {result.stderr}"
    );
    assert len(result.stdout) > 0;
    assert 'function greet(name = "World") {' in result.stdout;
}

test "empty file generates minimal js" {
    temp_path = write_temp_jac("\"\"\"Empty file for smoke testing.\"\"\"\n");

    try {
        js_code = compile_fixture_to_js(temp_path);
        assert len(js_code) < 100;
        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "type to typeof transformation" {
    jac_code = "\"\"\"Test type() to typeof conversion.\"\"\"\n\ncl def check_types() {\n    x = 42;\n    y = \"hello\";\n    my_obj = {\"key\": \"value\"};\n    arr = [1, 2, 3];\n\n    t1 = type(x);\n    t2 = type(y);\n    t3 = type(my_obj);\n    t4 = type(arr[0]);\n\n    return t1;\n}\n";

    temp_path = write_temp_jac(jac_code);

    try {
        js_code = compile_fixture_to_js(temp_path);

        for pattern in ["typeof x", "typeof y", "typeof my_obj", "typeof arr[0]"] {
            assert pattern in js_code;
        }
        assert "type(" not in js_code;
        assert js_code.count("typeof") == 4;
        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "category1 named imports generate correct js" {
    fixture_file_path = os.path.join(FIXTURES, "category1_named_imports.jac");
    js_code = compile_fixture_to_js(fixture_file_path);

    imports = [
        "import { useState } from \"react\";",
        "import { map, filter, reduce } from \"lodash\";",
        "import { get as httpGet } from \"axios\";",
        "import { createApp, ref as reactive, computed } from \"vue\";",
        "import { helper } from \"./utils.js\";",
        "import { formatter as format } from \"../lib.js\";",
        "import { settings } from \"../../config.js\";",
        "import { renderJsxTree, jacLogin, jacLogout } from \"@jac/runtime\";",

    ];
    for pattern in imports {
        assert pattern in js_code;
    }

    assert "function example_usage()" in js_code;
    for pattern in ["from react import", "from lodash import"] {
        assert pattern not in js_code;
    }
    assert_balanced_syntax(js_code, fixture_file_path);
}

test "category2 default imports generate correct js" {
    fixture_file_path = os.path.join(FIXTURES, "category2_default_imports.jac");
    js_code = compile_fixture_to_js(fixture_file_path);

    imports = [
        "import React from \"react\";",
        "import axios from \"axios\";",
        "import Vue from \"vue\";",
        "import Button from \"./components/Button.js\";",
        "import utils from \"../lib/utils.js\";",

    ];
    for pattern in imports {
        assert pattern in js_code;
    }

    assert "function example_usage()" in js_code;
    for pattern in ["import { React }", "import { axios }", "import { Vue }"] {
        assert pattern not in js_code;
    }
    assert_balanced_syntax(js_code, fixture_file_path);
}

test "category4 namespace imports generate correct js" {
    fixture_file_path = os.path.join(FIXTURES, "category4_namespace_imports.jac");
    js_code = compile_fixture_to_js(fixture_file_path);

    imports = [
        "import * as React from \"react\";",
        "import * as _ from \"lodash\";",
        "import * as DateUtils from \"dateutils\";",
        "import * as utils from \"./utils.js\";",
        "import * as helpers from \"../lib/helpers.js\";",

    ];
    for pattern in imports {
        assert pattern in js_code;
    }

    assert "function example_usage()" in js_code;
    for pattern in ["import { * }", "import { * as"] {
        assert pattern not in js_code;
    }
    assert_balanced_syntax(js_code, fixture_file_path);
}

test "atom trailer starts with specialvaref js" {
    fixture_file_path = os.path.join(FIXTURES, "root_render.jac");
    js_code = compile_fixture_to_js(fixture_file_path);

    assert "root.render();" in js_code;
    assert "obj" not in js_code;
}

test "assignment inside globvar js" {
    fixture_file_path = os.path.join(FIXTURES, "js_gen_bug.jac");
    js_code = compile_fixture_to_js(fixture_file_path);
    expected_generated_code = ["let setB = item => {", "item.b = 90;", ];
    for pattern in expected_generated_code {
        assert pattern in js_code;
    }
}

test "hyphenated package imports generate correct js" {
    fixture_file_path = os.path.join(FIXTURES, "hyphenated_imports.jac");
    js_code = compile_fixture_to_js(fixture_file_path);

    imports = [
        "import { render, hydrate } from \"react-dom\";",
        "import { render as renderDOM } from \"react-dom\";",
        "import * as ReactDOM from \"react-dom\";",
        "import ReactDOMDefault from \"react-dom\";",
        "import RD, { createPortal } from \"react-dom\";",
        "import styled from \"styled-components\";",
        "import { format, parse, addDays } from \"date-fns\";",
        "import { BrowserRouter, Route, Link } from \"react-router-dom\";",
        "import { useState, useEffect } from \"react\";",
        "import { map, filter } from \"lodash\";",

    ];
    for pattern in imports {
        assert pattern in js_code;
    }

    assert "function TestComponent()" in js_code;
    for pattern in ["from react-dom import", "from 'react-dom' import"] {
        assert pattern not in js_code;
    }
    assert_balanced_syntax(js_code, fixture_file_path);
}

test "relative imports include js extension" {
    jac_code = "\"\"\"Test relative imports with .js extension.\"\"\"\n\ncl {\n# Single dot relative import\nimport from .utils { MessageFormatter }\n\n# Double dot relative import\nimport from ..lib { formatter }\n\n# Triple dot relative import\nimport from ...config { settings }\n\n# Module name with dots (should still get .js)\nimport from .components.Button { Button }\n\n# Using imported functions\ndef test_usage() {\n    fmt = MessageFormatter();\n    return fmt.format(\"test\");\n}\n}\n";

    temp_path = write_temp_jac(jac_code);

    try {
        js_code = compile_fixture_to_js(temp_path);

        imports = [
            "import { MessageFormatter } from \"./utils.js\";",
            "import { formatter } from \"../lib.js\";",
            "import { settings } from \"../../config.js\";",
            "import { Button } from \"./components/Button.js\";",

        ];
        for pattern in imports {
            assert pattern in js_code;
        }

        assert "function test_usage()" in js_code;

        # Verify all relative imports have .js extension
        import_lines = [
            line
            for line in js_code.split("\n")
            if "import" in line and "from" in line
        ];
        relative_imports = [
            line
            for line in import_lines
            if "./" in line or "../" in line
        ];
        for line in relative_imports {
            assert ".js\"" in line or ".js'" in line , (
                f"Relative import missing .js: {line}"
            );
        }

        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "side effect imports generate correct js" {
    fixture_file_path = os.path.join(FIXTURES, "side_effect_imports.jac");
    js_code = compile_fixture_to_js(fixture_file_path);

    imports = [
        "import \"mytest/side_effects\";",
        "import \"./styles/side_effects.css\";",
        "import \"bootstrap/dist/css/bootstrap.min.css\";",

    ];
    for pattern in imports {
        assert pattern in js_code;
    }

    assert_balanced_syntax(js_code, fixture_file_path);
}

test "fstring simple variable interpolation" {
    jac_code = "\"\"\"Test f-string with simple variables.\"\"\"\n\ncl def greet_user(name: str, age: int) -> str {\n    return f\"Hello, {name}! You are {age} years old.\";\n}\n";

    temp_path = write_temp_jac(jac_code);

    try {
        js_code = compile_fixture_to_js(temp_path);

        assert "function greet_user" in js_code;
        assert "`" in js_code;
        for pattern in ["${name}", "${age}", "Hello,", "You are", "years old."] {
            assert pattern in js_code;
        }
        assert "`Hello, ${name}! You are ${age} years old.`" in js_code;
        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "fstring with expressions" {
    jac_code = "\"\"\"Test f-string with expressions.\"\"\"\n\ncl def calculate_message(x: int, y: int) -> str {\n    return f\"The sum of {x} and {y} is {x + y}\";\n}\n\ncl def conditional_message(score: int) -> str {\n    return f\"Score: {score}, Status: {score >= 60}\";\n}\n";

    temp_path = write_temp_jac(jac_code);

    try {
        js_code = compile_fixture_to_js(temp_path);

        for pattern in [
            "function calculate_message",
            "function conditional_message",

        ] {
            assert pattern in js_code;
        }

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

        ] {
            assert pattern in js_code;
        }

        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "fstring advanced fixture template literals" {
    advanced_fixture = "advanced_language_features.jac";
    js_code = compile_fixture_to_js(advanced_fixture, FIXTURES);

    assert "function template_literal_examples" in js_code;
    assert js_code.count("`") >= 2;
    for pattern in [
        "${",
        "${user}",
        "${score}",
        "${status}",
        "scored",
        "which is a",

    ] {
        assert pattern in js_code;
    }
}

test "fstring edge cases" {
    jac_code = "\"\"\"Test f-string edge cases.\"\"\"\n\ncl def test_edge_cases() -> dict {\n    name = \"Alice\";\n    value = 42;\n\n    # Text only (no interpolation)\n    text_only = f\"This is just plain text\";\n\n    # Expression only (no static text)\n    expr_only = f\"{value}\";\n\n    # Multiple consecutive expressions\n    consecutive = f\"{name}{value}\";\n\n    # Mixed with spaces\n    mixed = f\"Name: {name}, Value: {value}\";\n\n    return {\"text\": text_only, \"expr\": expr_only, \"cons\": consecutive, \"mixed\": mixed};\n}\n";

    temp_path = write_temp_jac(jac_code);

    try {
        js_code = compile_fixture_to_js(temp_path);

        assert "function test_edge_cases" in js_code;
        for pattern in [
            "`This is just plain text`",
            "`${value}`",
            "`${name}${value}`",
            "Name:",
            "Value:",
            "${name}",
            "${value}",

        ] {
            assert pattern in js_code;
        }
        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "fstring no concatenation operators" {
    jac_code = "\"\"\"Test that f-strings use template literals, not concatenation.\"\"\"\n\ncl def format_message(user: str, count: int) -> str {\n    return f\"User {user} has {count} items\";\n}\n";

    temp_path = write_temp_jac(jac_code);

    try {
        js_code = compile_fixture_to_js(temp_path);

        for pattern in ["`", "${user}", "${count}"] {
            assert pattern in js_code;
        }

        # Verify return uses template literal, not concatenation
        return_statements = [
            line
            for line in js_code.split("\n")
            if "return" in line
        ];
        fstring_returns = [
            line
            for line in return_statements
            if "${" in line
        ];
        for ret_line in fstring_returns {
            assert ret_line.count("`") == 2 , (
                f"Expected single template literal: {ret_line}"
            );
        }

        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "keyword variables" {
    advanced_fixture = "advanced_language_features.jac";
    js_code = compile_fixture_to_js(advanced_fixture, FIXTURES);

    assert "function def(from, class) {" in js_code;
    for pattern in [
        "console.log(\"From is:\", from);",
        "console.log(\"Class is:\", class);",

    ] {
        assert pattern in js_code;
    }
}

test "separated files" {
    # Compile the standalone client module directly
    client_fixture = "separated_client.cl.jac";
    js_code = compile_fixture_to_js(client_fixture, FIXTURES);

    # Check the spawned walker function is present
    assert "let response = await __jacSpawn(" in js_code;
    # `input` is destructured from useState (external React typings) so its
    # static type is unknown — `.strip()` routes through the polymorphic
    # runtime dispatcher instead of leaking the Python method name.
    assert (
        "__jacSpawn(\"create_todo\", \"\", {\"text\": _jac.poly.call(input, \"strip\")});" in js_code
    );
}

test "separated defpub generates rpc stubs" {
    # Compile the client module directly. It uses `sv import` to reference
    # def:pub functions defined in separated_defpub.jac (the main module).
    fixture = "separated_defpub_client.cl.jac";
    js_code = compile_fixture_to_js(fixture, FIXTURES);

    # The sv-imported def:pub functions must produce __jacCallFunction stubs
    assert "__jacCallFunction" in js_code , (
        "sv import of def:pub functions must generate __jacCallFunction RPC stubs"
    );

    # Each def:pub function should have a stub with the correct name
    for func_name in ["add_task", "get_tasks", "toggle_task"] {
        expected = '__jacCallFunction("' + func_name + '"';
        assert expected in js_code , (
            "Missing RPC stub for def:pub function '" + func_name + "'"
        );
    }

    # The __jacCallFunction import should be present
    assert 'import { __jacCallFunction } from "@jac/runtime";' in js_code , (
        "__jacCallFunction import from @jac/runtime is required"
    );

    # Stubs should be async functions
    for func_name in ["add_task", "get_tasks", "toggle_task"] {
        assert ("async function " + func_name + "(") in js_code , (
            "RPC stub for '" + func_name + "' should be an async function"
        );
    }

    assert_balanced_syntax(js_code, fixture);
}

test "sv import kwargs preserve names in jac call function" {
    # Regression for issue #5852.  Calling an sv-imported def:pub function
    # with kwargs syntax (e.g. ``greet(name=x)``) must compile to the same
    # ``__jacCallFunction("greet", {"name": x})`` shape that the positional
    # form produces.  Previously the kwargs were silently dropped, emitting
    # ``__jacCallFunction("greet", {})`` and causing a server 422.
    fixture = "sv_import_kwargs_client.cl.jac";
    js_code = compile_fixture_to_js(fixture, FIXTURES);

    # Pure-kwargs single arg: ``greet(name=input_text)``
    assert '__jacCallFunction("greet", {"name": input_text})' in js_code , (
        "Single-kwarg call must propagate the name into the args object;\n" + "got:\n" + js_code
    );

    # Pure-kwargs out-of-order: ``add_pair(b=2, a=1)`` — both keys must be
    # present in the args object regardless of source order.
    assert (
        '__jacCallFunction("add_pair", {"b": 2, "a": 1})' in js_code
        or '__jacCallFunction("add_pair", {"a": 1, "b": 2})' in js_code
    ) , (
        "Kwargs-only call must include all kwarg keys in the args object;\n" + "got:\n" + js_code
    );

    # Mixed positional + kwarg: ``add_pair(1, b=2)`` — first param mapped
    # by position to its server-side name, second carried by kwarg key.
    assert '__jacCallFunction("add_pair", {"a": 1, "b": 2})' in js_code , (
        "Mixed positional/kwarg call must merge both into the args object;\n" + "got:\n" + js_code
    );

    # ``**dict`` spread against a known signature can lower to declared
    # parameter-key reads, avoiding the old single-object positional shape.
    assert '__jacCallFunction("add_pair", {"a": kw["a"], "b": kw["b"]})' in js_code , (
        "**dict spread against known signature must compile to keyed parameter reads;\n" + "got:\n" + js_code
    );

    # Sanity: the obvious bug-shape — empty args object — must not appear
    # for any of these named calls.
    assert '__jacCallFunction("greet", {})' not in js_code , (
        "Bug regression: kwargs were dropped, emitting empty args object."
    );
    assert '__jacCallFunction("add_pair", {})' not in js_code , (
        "Bug regression: kwargs were dropped, emitting empty args object."
    );

    assert_balanced_syntax(js_code, fixture);
}

test "sv import kwargs preserve names in production jac2js path" {
    fixture = "sv_import_kwargs_client.cl.jac";
    js_code = compile_fixture_to_js_production(fixture, FIXTURES);

    assert '__jacCallFunction("greet", {"name": input_text})' in js_code , (
        "Production jac2js path must lower sv-import kwargs directly into the RPC args object;\n" + "got:\n" + js_code
    );
    assert "await greet({name: input_text})" not in js_code , (
        "Production jac2js path must not pass kwargs object into the generated RPC wrapper;\n" + "got:\n" + js_code
    );
    assert '__jacCallFunction("greet", {})' not in js_code , (
        "Production jac2js path must not emit an empty RPC args object for kwargs calls."
    );
}

test "sv import wrapper covers posonly and kwonly params" {
    # Regression for the latent stub-generation bug: ``_generate_sv_import_stubs``
    # used to walk only ``sig.params`` (regular non-posonly non-kwonly), so
    # posonly/kwonly params silently disappeared from the generated wrapper —
    # both from its JS function signature and from the ``__jacCallFunction``
    # args object.  After unifying on ``_param_names_from_ability``, all three
    # buckets are walked and the wrapper's shape matches the source ability.
    fixture = "sv_import_posonly_kwonly_client.cl.jac";
    js_code = compile_fixture_to_js_production(fixture, FIXTURES);
    compact_js = js_code.replace("\n", "").replace(" ", "");

    # Wrapper signature must list params in declared order — filter (posonly),
    # query (regular), scope (kwonly).
    assert "asyncfunctionquery(filter,query,scope)" in compact_js , (
        "sv-import wrapper must include posonly + kwonly params in its JS " + "signature, not silently drop them;\ngot:\n" + js_code
    );
    # All three params must appear in the RPC args object the wrapper posts.
    assert (
        '__jacCallFunction("query",{"filter":filter,"query":query,"scope":scope})' in compact_js
    ) , (
        "sv-import wrapper must forward posonly + kwonly params in the RPC " + "args object;\ngot:\n" + js_code
    );
    # Pre-fix bug shape: a one-arg wrapper that posts only the regular param.
    assert "asyncfunctionquery(query)" not in compact_js , (
        "Wrapper must not regress to walking only sig.params (which would drop " + "posonly + kwonly);\ngot:\n" + js_code
    );
}

test "plain client kwargs lower to ordered js arguments" {
    fixture = "plain_kwargs_client.cl.jac";
    js_code = compile_fixture_to_js_production(fixture, FIXTURES);
    compact_js = js_code.replace("\n", "").replace(" ", "");

    assert "setTotal(add(5, 10));" in js_code , (
        "Known Jac function kwargs must lower to ordered JS positional args;\n" + "got:\n" + js_code
    );
    assert "setMixed(add(1, 2));" in js_code , (
        "Mixed positional/kwarg call must preserve positional args and order kwargs by signature;\n" + "got:\n" + js_code
    );
    assert "function add_defaults(a = 1, b = 2)" in js_code , (
        "Jac default parameter values must be preserved in emitted JS function signatures;\n" + "got:\n" + js_code
    );
    assert "setDefaulted(add_defaults(undefined, 99));" in js_code , (
        "Skipping an earlier defaulted param must emit an undefined placeholder, not collapse positions;\n" + "got:\n" + js_code
    );
    assert 'setSpread_total(add(kw["a"], kw["b"]));' in js_code , (
        "Known **kwargs calls must lower to declared-parameter property reads;\n" + "got:\n" + js_code
    );
    assert compact_js.count(")(get_kw()))") == 1 , (
        "Complex **kwargs source must be evaluated exactly once;\n" + "got:\n" + js_code
    );
    assert (
        'setSpread_call_total((__jac_kwargs=>add3(__jac_kwargs["a"],__jac_kwargs["b"],__jac_kwargs["c"]))(get_kw()));' in compact_js
    ) , (
        "Known **function_call() spread must lower through a single-evaluation temp IIFE;\n" + "got:\n" + js_code
    );
    assert (
        'setSpread_merge_total((__jac_kwargs=>add3(__jac_kwargs["a"],__jac_kwargs["b"],__jac_kwargs["c"]))({...kw1,...kw2}));' in compact_js
    ) , (
        "Multiple **kwargs spreads must merge earlier and later sources before keyed reads;\n" + "got:\n" + js_code
    );
    assert (
        'setSpread_override_total((__jac_kwargs=>add3(__jac_kwargs["a"],99,__jac_kwargs["c"]))({...kw1,...kw2}));' in compact_js
    ) , (
        "Explicit kwargs must override **spread values while preserving other merged keys;\n" + "got:\n" + js_code
    );
    assert "setMethod_total(counter.bump(5, 3));" in js_code , (
        "Known method kwargs must lower to ordered JS positional args;\n" + "got:\n" + js_code
    );
    assert "add({b: 10, a: 5})" not in js_code , (
        "Plain kwargs must not be passed as one positional object argument;\n" + "got:\n" + js_code
    );
    assert "add_defaults(99)" not in js_code , (
        "Defaulted kwargs must not collapse missing earlier params;\n" + "got:\n" + js_code
    );
    assert "counter.bump({amount: 5, mul: 3})" not in js_code , (
        "Method kwargs must not be passed as one positional object argument;\n" + "got:\n" + js_code
    );
}

test "sv import duplicate kwarg is a compile error" {
    # Calling ``greet(input_text, name=other)`` gives the ``name`` parameter
    # twice — once positionally and once by keyword.  This mirrors Python's
    # ``TypeError: got multiple values for argument 'name'`` and must be
    # reported as a compile-time error so the build fails fast rather than
    # silently emitting a JS object with a duplicated key.
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.compiler.passes.ecmascript { EsastGenPass }

    fixture = os.path.join(FIXTURES, "sv_import_kwargs_dup.cl.jac");
    prog = JacProgram();
    ir = prog.compile(file_path=fixture, no_cgen=True, type_check=True);
    EsastGenPass(ir_in=ir, prog=prog);

    dup_errs = [
        e
        for e in prog.errors_had
        if "given both positionally and by keyword" in str(e)
    ];
    assert len(dup_errs) == 1 , (
        "Expected exactly one E5080 collision diagnostic, got " + str(
            [str(e) for e in prog.errors_had]
        )
    );
    assert "name" in str(dup_errs[0]) and "greet" in str(dup_errs[0]);
}

test "cl.jac with impl.jac does not duplicate __jacCallFunction import" {
    # When a .cl.jac file has a separate .impl.jac file, both the main pass
    # and the child pass for the impl module may independently inject
    # __jacCallFunction from @jac/runtime. The import must appear only once.
    fixture = "defpub_impl_dedup.cl.jac";
    js_code = compile_fixture_to_js(fixture, FIXTURES);

    # The import must be present
    import_line = 'import { __jacCallFunction } from "@jac/runtime";';
    assert import_line in js_code , (
        "__jacCallFunction import from @jac/runtime is required"
    );

    # It must appear exactly once (no duplicates)
    import_count = js_code.count(import_line);
    assert import_count == 1 , (
        f"Expected exactly 1 __jacCallFunction import, found {import_count}"
    );

    assert_balanced_syntax(js_code, fixture);
}

test "lexer does not treat comparison lt as jsx tag" {
    # BUG: `i<points` in a for-loop causes the lexer to enter JSX_TAG
    # mode because `<` followed by an alpha char is always treated as a
    # JSX opening tag.  This corrupts the mode state machine, causing
    # the compiler to hang in an infinite loop.
    fixture = "jsx_lt_comparison_bug.cl.jac";
    js_code = compile_fixture_to_js(fixture, FIXTURES);

    # The for-loop comparison must compile to JS `<` operator, NOT a JSX tag.
    assert "for " in js_code , "for-loop should be present in output";
    assert "i < points.length" in js_code or "(i < points.length)" in js_code , (
        "Comparison `i<points.length` must emit as `<` operator, not JSX"
    );
    assert "filter_points" in js_code;
    assert_balanced_syntax(js_code, fixture);
}

test "jsx text with quotes does not produce double-double quotes" {
    # BUG: JSX text content containing quote characters (e.g. "text")
    # is wrapped in an extra pair of quotes by gen_literal, producing
    # ""text"" which is invalid JavaScript.
    fixture = "jsx_text_quotes_bug.cl.jac";
    js_code = compile_fixture_to_js(fixture, FIXTURES);

    # The generated JS must NOT contain unescaped double-double quotes.
    # Valid:   "\"Try: show all to reset\""  (escaped inner quotes)
    # Invalid: ""Try: show all to reset""    (raw double-double quotes)
    import re;
    unescaped_double_quotes = re.findall(r'(?<!\\)""', js_code);
    assert len(unescaped_double_quotes) == 0 , (
        "Unescaped double-double quotes found in generated JS — "
        f"quote characters in JSX text are being double-wrapped:\n{js_code}"
    );

    # The text content should appear in the output with escaped quotes.
    assert "Try: show all to reset" in js_code , (
        "JSX text content with quotes should appear in output"
    );
    assert_balanced_syntax(js_code, fixture);
}

test "any typed callee emits plain call not new expression" {
    # BUG: `Any` is internally represented as a `ClassType` with the
    # `Instance` flag, so the ES codegen previously emitted
    # `new handler(payload)` for any callee whose type was a ClassType,
    # including variables typed as `Any`. This broke async callbacks
    # passed between components, since `new` makes JavaScript try to
    # construct an object rather than invoke the function.
    fixture = "any_callee_not_new.jac";
    js_code = compile_fixture_to_js(fixture, FIXTURES);

    # Plain invocation must be emitted, not `new ...()`.
    assert "await handler(payload)" in js_code , (
        f"Expected plain `await handler(payload)` call, got:\n{js_code}"
    );
    assert "await new handler" not in js_code , (
        f"`Any`-typed async callee must not be emitted as `new`:\n{js_code}"
    );
    assert "new handler(" not in js_code , (
        f"`Any`-typed sync callee must not be emitted as `new`:\n{js_code}"
    );
    assert_balanced_syntax(js_code, fixture);
}

test "jac runtime is defined when referenced in generated js" {
    # When the compiler emits _jac.* calls (e.g. _jac.list.sort,
    # _jac.str.capitalize), the generated JS must define _jac.
    # Previously _jac was referenced but never provided, causing
    # "ReferenceError: _jac is not defined" at runtime.
    fixture = "prim_jac_runtime.jac";
    js_code = compile_fixture_to_js(fixture, FIXTURES);

    # The compiled JS should contain _jac.* calls for these operations
    assert "_jac." in js_code , (
        "Expected _jac.* runtime calls in generated JS for primitives "
        "that have no direct JS equivalent"
    );

    # The _jac namespace must be defined (inlined as const _jac = {...})
    assert "const _jac" in js_code , (
        "Generated JS references _jac but never defines it. "
        "This causes 'ReferenceError: _jac is not defined' at runtime."
    );

    # Verify the runtime object contains the expected namespaces
    for ns in ["str:", "list:", "dict:", "builtin:"] {
        assert ns in js_code , (f"_jac runtime missing namespace '{ns.rstrip(':')}'");
    }

    assert_balanced_syntax(js_code, fixture);
}

test "convert to js import path preserves js format" {
    # Paths already in JavaScript format should pass through unchanged
    assert convert_to_js_import_path("./styles.css") == "./styles.css";
    assert convert_to_js_import_path("../lib/utils.js") == "../lib/utils.js";
    assert convert_to_js_import_path("../../config.json") == "../../config.json";

    # Jac-style paths should still be converted correctly
    assert convert_to_js_import_path(".utils") == "./utils.js";
    assert convert_to_js_import_path("..lib") == "../lib.js";
    assert convert_to_js_import_path("...config") == "../../config.js";

    # CSS imports in Jac format should convert correctly
    assert convert_to_js_import_path(".styles.css") == "./styles.css";

    # NPM packages should pass through unchanged
    assert convert_to_js_import_path("react") == "react";
    assert convert_to_js_import_path("lodash") == "lodash";
}

test "for-of tuple targets destructure into binding patterns" {
    jac_code = (
        "cl def f() {\n"
        "    pairs = [[1, 2]];\n"
        "    nested = [[[1, 2], 3]];\n"
        "    rows = [[1, 2, 3]];\n"
        "    for x in pairs {  }\n"
        "    for (a, b) in pairs {  }\n"
        "    for (i, p) in enumerate(pairs) {  }\n"
        "    for ((c, d), e) in nested {  }\n"
        "    for (g, *rest) in rows {  }\n"
        "    return 0;\n"
        "}\n"
    );
    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);
        assert "for (const x of pairs)" in js_code;
        assert "for (const [a, b] of pairs)" in js_code;
        assert "for (const [i, p] of _jac.builtin.enumerate(pairs))" in js_code;
        assert "for (const [[c, d], e] of nested)" in js_code;
        assert "for (const [g, ...rest] of rows)" in js_code;
        assert "_item" not in js_code;
        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

# ============================================================================
# Comprehension → JavaScript Tests
# ============================================================================
test "compr list basic map" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # list_compr_map: [x * 2 for x in items] → items.map(x => (x * 2))
    assert ".map(" in js_code , "List comprehension should generate .map() call";
    assert "x =>" in js_code , "Arrow function should use comprehension variable";
}

test "compr list filter only" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # list_compr_filter: [x for x in items if x > 0] → items.filter(x => (x > 0))
    assert ".filter(" in js_code , "Filtered comprehension should generate .filter() call";
    assert "(x > 0)" in js_code , "Filter condition should be preserved";
}

test "compr list map and filter" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # list_compr_map_filter: [x * 2 for x in items if x > 0]
    #   → items.filter(x => (x > 0)).map(x => (x * 2))
    assert ".filter(" in js_code and ".map(" in js_code , (
        "Map+filter comprehension should chain .filter().map()"
    );
}

test "compr list multiple filters" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # list_compr_multi_filter: [x for x in items if x > 0 if x < 100]
    #   → items.filter(x => (x > 0)).filter(x => (x < 100))
    assert "(x < 100)" in js_code , ("Second filter condition should appear in output");
}

test "compr list method call" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # list_compr_method: [x.strip() for x in items] → items.map(x => _jac.poly.call(x, "strip"))
    # `items` is typed as bare `list` (no element type), so x is Unknown.
    # Pre-#5508 the codegen leaked the Python `.strip()` verbatim into JS,
    # which crashes at runtime. The polymorphic runtime dispatcher routes
    # to `String.prototype.trim` for actual strings.
    assert "_jac.poly.call(x, \"strip\")" in js_code , (
        "Untyped element method calls in comprehensions should route "
        "through the _jac.poly.call runtime dispatcher"
    );
}

test "str methods on local vars and chained calls" {
    js_code = compile_fixture_to_js("str_method_chaining.cl.jac", FIXTURES);
    assert "temp.toLowerCase()" in js_code , "str.lower() on local var should map to .toLowerCase()";
    assert "text.trim().toLowerCase()" in js_code , "chained str.strip().lower() should map to .trim().toLowerCase()";
    assert "text.toUpperCase().trim()" in js_code , "chained str.upper().strip() should map to .toUpperCase().trim()";
    assert "text.trim().toUpperCase()" in js_code , "chained str.strip().upper() should map to .trim().toUpperCase()";
    assert "text.toUpperCase().trim().toLowerCase()" in js_code , "triple-chained str.upper().strip().lower() should map to .toUpperCase().trim().toLowerCase()";
}

test "issue 5508 case1 in operator on str method call" {
    # Regression for jaseci-labs/jaseci#5508 case 1.
    # `"a" in name.lower()` was emitting a raw JS `in` operator on a string
    # because operator-side dispatch (_try_primitive_op) did not walk the MRO
    # to recognize the LiteralString return type as `str`. The receiver of
    # `.lower()` got translated to `.toLowerCase()`, but the `in` operator
    # itself was left untranslated, crashing at runtime in the browser.
    js_code = compile_fixture_to_js("issue_5508_str_method_dispatch.cl.jac", FIXTURES);
    assert "name.toLowerCase().includes(\"a\")" in js_code , (
        "`x in str_method()` should lower to .includes() on the method result"
    );
    assert "(\"a\" in name.toLowerCase())" not in js_code , (
        "raw JS `in` operator on a string would crash at runtime"
    );
}

test "poly get dispatches through runtime helper for untyped receivers" {
    js_code = compile_fixture_to_js("poly_get_dispatch.cl.jac", FIXTURES);

    # Pluck out the user-compiled function body (skip the injected _jac
    # runtime, which legitimately contains `.get(` inside its dispatcher).
    fn_idx = js_code.find("function test_poly_get");
    assert fn_idx >= 0 , "compiled function test_poly_get must be present";
    user_chunk = js_code[fn_idx:fn_idx + 500];

    # When the receiver's static type is unknown, .get() must route through
    # the _jac.poly.call runtime dispatcher (with the method name as a string
    # argument) instead of leaking the Python method name verbatim into JS.
    assert "_jac.poly.call(" in user_chunk and '"get"' in user_chunk , (
        "Untyped .get() must route through the _jac.poly.call() dispatcher;\n"
        "got:\n" + user_chunk
    );
    # `_jac.poly.call(mapping, "get", "a")` does NOT contain `.get("`, but a
    # leak like `mapping.get("a")` would — so this cleanly catches a raw
    # Python method name escaping into the JS output.
    assert '.get("' not in user_chunk , (
        "Python `.get()` should not appear verbatim in compiled user JS"
    );

    # Verify the emitted JS actually runs and produces correct results.
    wrapper = js_code + "\nconsole.log(JSON.stringify(test_poly_get()));\n";
    result = subprocess.run(
        ["node", "--input-type=module", "-e", wrapper],
        capture_output=True,
        text=True,
        timeout=30
    );
    assert result.returncode == 0 , (
        "poly.get dispatch crashed in Node:\n" "stdout=" + result.stdout + "\nstderr=" + result.stderr + "\njs:\n" + js_code
    );
    import json;
    got: dict[str, any] = json.loads(result.stdout.strip());
    assert "hit" in got and got["hit"] == 1 , (
        "poly.get hit must return existing value 1, got " + str(got)
    );
    assert "miss" in got and got["miss"] == -1 , (
        "poly.get miss must return default -1, got " + str(got)
    );

    assert_balanced_syntax(js_code, "poly_get_dispatch.cl.jac");
}

test "poly get dispatches to custom obj method not plain-object bracket" {
    js_code = compile_fixture_to_js("poly_get_custom_obj.cl.jac", FIXTURES);

    fn_idx = js_code.find("function test_poly_get_custom");
    assert fn_idx >= 0 , "compiled function test_poly_get_custom must be present";
    user_chunk = js_code[fn_idx:fn_idx + 600];

    # Must route through the dispatcher because the receiver is any-typed.
    assert "_jac.poly.call(" in user_chunk and '"get"' in user_chunk , (
        "Untyped .get() on a custom obj must route through _jac.poly.call();\n"
        "got:\n" + user_chunk
    );

    # Verify runtime behavior: the dispatcher must detect the user-defined
    # `Cache.get` method and call it (returning 42 for "x"), rather than
    # treating the instance as a plain-object dict — which would miss keys
    # stored in the internal `data` dict and return the default (-1).
    wrapper = js_code + "\nconsole.log(JSON.stringify(test_poly_get_custom()));\n";
    result = subprocess.run(
        ["node", "--input-type=module", "-e", wrapper],
        capture_output=True,
        text=True,
        timeout=30
    );
    assert result.returncode == 0 , (
        "poly.get custom-obj dispatch crashed in Node:\n" "stdout=" + result.stdout + "\nstderr=" + result.stderr + "\njs:\n" + js_code
    );
    import json;
    got: dict[str, any] = json.loads(result.stdout.strip());
    assert "hit" in got and got["hit"] == 42 , (
        "poly.get on custom obj must call the object's .get() method and "
        "return 42, got " + str(got)
    );
    assert "miss" in got and got["miss"] == -1 , (
        "poly.get on custom obj must return default -1 for missing key, got " + str(got)
    );

    assert_balanced_syntax(js_code, "poly_get_custom_obj.cl.jac");
}

test "poly call dispatches dict/list/set/user methods on untyped receivers" {
    js_code = compile_fixture_to_js("poly_dispatch_complete.cl.jac", FIXTURES);

    # Every untyped method call routes through the single dispatcher; no
    # Python method name leaks verbatim into the compiled user code.
    fn_idx = js_code.find("function test_poly_complete");
    assert fn_idx >= 0 , "compiled function test_poly_complete must be present";
    user_chunk = js_code[fn_idx:fn_idx + 1200];
    assert "_jac.poly.call(" in user_chunk , (
        "Untyped container methods must route through _jac.poly.call();\n"
        "got:\n" + user_chunk
    );
    for leaked in [".keys(", ".values(", ".update(", ".append(", ".discard("] {
        assert leaked not in user_chunk , (
            "Python method " + leaked + ") leaked verbatim into compiled JS:\n" + user_chunk
        );
    }

    wrapper = (
        js_code + "\nconsole.log(JSON.stringify(test_poly_complete()));" + "\nconsole.log(JSON.stringify(test_poly_attribute_error()));\n"
    );
    result = subprocess.run(
        ["node", "--input-type=module", "-e", wrapper],
        capture_output=True,
        text=True,
        timeout=30
    );
    assert result.returncode == 0 , (
        "poly.call dispatch crashed in Node:\nstdout=" + result.stdout + "\nstderr=" + result.stderr + "\njs:\n" + js_code
    );
    import json;
    lines = result.stdout.strip().split("\n");
    got: dict[str, any] = json.loads(lines[0]);
    raised = json.loads(lines[1]);

    # dict: keys/values captured before update; get after update.
    assert got["keys"] == ["a", "b"] , ("dict.keys mismatch: " + str(got));
    assert got["vals"] == [1, 2] , ("dict.values mismatch: " + str(got));
    assert got["has_c"] == 3 , ("dict.update+get mismatch: " + str(got));
    # The fixed Python dict.get semantics: present-but-null returns null,
    # absent returns the default.
    assert got["null_hit"] is None , (
        "dict.get on a present null key must return null, not the default: " + str(got)
    );
    assert got["missing"] == -1 , (
        "dict.get on an absent key must return the default: " + str(got)
    );
    # list: append + sort + count.
    assert got["lst"] == [1, 2, 3, 4] , ("list.append/sort mismatch: " + str(got));
    assert got["cnt"] == 1 , ("list.count mismatch: " + str(got));
    # set: add + discard reflected by membership.
    assert got["has_three"] == True , ("set.add mismatch: " + str(got));
    assert got["has_one"] == False , ("set.discard mismatch: " + str(got));
    # user-defined method name colliding with a primitive: forwarded.
    assert got["box_count"] == 3 , (
        "primitive-named user method must be forwarded, not run as a list op: " + str(
            got
        )
    );
    # JS-global method on a function-typed receiver (Object.keys): the
    # dispatcher must forward to the function's own method, not throw.
    assert got["obj_keys"] == ["p", "q"] , (
        "Object.keys via the dispatcher must forward to the real method: " + str(got)
    );
    # The dispatcher raises a catchable AttributeError for an unsupported op.
    assert raised == True , (
        "an eligible method on an incompatible runtime type must raise "
        "AttributeError, not silently return a wrong value"
    );

    assert_balanced_syntax(js_code, "poly_dispatch_complete.cl.jac");
}

test "issue 5508 case2 str methods on untyped receivers" {
    # Regression for jaseci-labs/jaseci#5508 case 2 (also covers #5453).
    # When the static type of the receiver is not provably `str` (props of
    # type `dict`, results of `or` widening, comprehension over untyped
    # list, etc.) the codegen used to emit Python method names verbatim
    # (`.upper`, `.strip`, `.lower`) which crash at runtime in JS. Fall
    # back to runtime-polymorphic helpers (`_jac.poly.*`) instead.
    js_code = compile_fixture_to_js("issue_5508_str_method_dispatch.cl.jac", FIXTURES);
    # Pluck out the user-compiled function bodies (slice from each function
    # so the injected _jac runtime is not scanned).
    user_chunks = [];
    for fn_name in ["case2_props_upper", "case2_props_strip", "case2_props_lower"] {
        idx = js_code.find("function " + fn_name);
        assert idx >= 0 , (f"missing compiled function {fn_name}");
        user_chunks.append(js_code[idx:idx + 400]);
    }
    user_code = "\n".join(user_chunks);
    # Untyped string methods must NOT survive verbatim into the user code.
    assert ".upper()" not in user_code , (
        "Python `.upper()` should not appear verbatim in compiled user JS"
    );
    assert ".strip()" not in user_code , (
        "Python `.strip()` should not appear verbatim in compiled user JS"
    );
    assert ".lower()" not in user_code , (
        "Python `.lower()` (without a static str type) should not appear "
        "verbatim in compiled user JS"
    );
    # Should route through the polymorphic runtime dispatcher, with the
    # method name carried as a string argument.
    assert "_jac.poly.call(" in user_code , (
        "Untyped str methods should route through the _jac.poly.call() dispatcher"
    );
    assert '"upper"' in user_code , (
        "Untyped .upper() should route through _jac.poly.call(.., \"upper\")"
    );
    assert '"strip"' in user_code , (
        "Untyped .strip() should route through _jac.poly.call(.., \"strip\")"
    );
    assert '"lower"' in user_code , (
        "Untyped .lower() should route through _jac.poly.call(.., \"lower\")"
    );
    # The _jac runtime must be injected when the dispatcher is used.
    assert "const _jac = {" in js_code , (
        "_jac runtime must be injected when _jac.poly.call is emitted"
    );
}

test "compr list ternary output" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # list_compr_ternary: [x if x > 0 else 0 for x in items]
    #   → items.map(x => (x > 0) ? x : 0)
    assert "?" in js_code and ":" in js_code , (
        "Ternary in comprehension output should generate JS conditional"
    );
}

test "compr set basic" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # set_compr_basic: {x * 2 for x in items} → new Set(items.map(x => (x * 2)))
    assert "new Set(" in js_code , (
        "Set comprehension should wrap result in new Set()"
    );
    assert "new Set(items.map(" in js_code , (
        "Set comprehension should be new Set(items.map(...))"
    );
}

test "compr set with filter" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # set_compr_filter: {x for x in items if x > 0}
    #   → new Set(items.filter(x => (x > 0)).map(x => x))
    #   or → new Set(items.filter(x => (x > 0)))
    assert "new Set(" in js_code , (
        "Filtered set comprehension should wrap in new Set()"
    );
}

test "compr dict basic" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # dict_compr_basic: {k: v for (k, v) in pairs}
    #   → Object.fromEntries(pairs.map(([k, v]) => [k, v]))
    assert "Object.fromEntries(" in js_code , (
        "Dict comprehension should use Object.fromEntries()"
    );
}

test "compr dict with filter" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # dict_compr_filter: {k: v for (k, v) in pairs if v > 0}
    #   → Object.fromEntries(pairs.filter(([k, v]) => (v > 0)).map(([k, v]) => [k, v]))
    assert "Object.fromEntries(" in js_code , (
        "Filtered dict comprehension should use Object.fromEntries()"
    );
    assert ".filter(" in js_code , (
        "Filtered dict comprehension should chain .filter()"
    );
}

test "compr dict transform" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # dict_compr_transform: {k: v * 2 for (k, v) in pairs}
    #   → Object.fromEntries(pairs.map(([k, v]) => [k, (v * 2)]))
    assert "Object.fromEntries(" in js_code , (
        "Dict comprehension with transform should use Object.fromEntries()"
    );
    assert "(v * 2)" in js_code , (
        "Dict comprehension should include value transform expression"
    );
}

test "compr generator basic" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # gen_compr_basic: list((x * 2 for x in items)) → items.map(x => (x * 2))
    # Generator expressions produce eager arrays in JS
    assert ".map(" in js_code , ("Generator expression should generate .map() call");
}

test "compr generator filter" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # gen_compr_filter: list((x for x in items if x > 0))
    #   → items.filter(x => (x > 0))
    assert ".filter(" in js_code , (
        "Filtered generator expression should generate .filter() call"
    );
}

test "compr nested basic" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # nested_compr_basic: [x + y for x in a for y in b]
    #   → a.flatMap(x => b.map(y => (x + y)))
    assert ".flatMap(" in js_code , (
        "Nested comprehension should generate .flatMap() for outer loop"
    );
}

test "compr nested with filter" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);

    # nested_compr_filter: [x + y for x in a for y in b if x != y]
    #   → a.flatMap(x => b.filter(y => (x !== y)).map(y => (x + y)))
    assert ".flatMap(" in js_code , (
        "Filtered nested comprehension should use .flatMap()"
    );
    assert "!==" in js_code , ("!= comparison should become !== in JavaScript");
}

test "compr balanced syntax" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);
    assert_balanced_syntax(js_code, "comprehensions.cl.jac");
}

test "compr no jac keywords" {
    js_code = compile_fixture_to_js("comprehensions.cl.jac", FIXTURES);
    assert_no_jac_keywords(js_code, "comprehensions.cl.jac");
}

test "await expression parenthesized as member expression object" {
    # BUG: When AwaitExpression is the object of a MemberExpression,
    # the unparser generates `await foo().prop` which JS parses as
    # `await (foo().prop)` instead of the intended `(await foo()).prop`.
    # This manifests at runtime when typed list returns use:
    #   await __jacCallFunction("get_items",{}).map(x => T.__from_wire(x))
    # which calls .map() on the Promise, not the resolved array.
    import from jaclang.compiler.passes.ecmascript.estree {
        AwaitExpression,
        CallExpression,
        MemberExpression,
        Identifier,
        ArrowFunctionExpression,
        Program,
        ExpressionStatement
    }

    # Build: (await fetchData()).map(x => x)
    await_call = AwaitExpression(
        argument=CallExpression(callee=Identifier(name="fetchData"), arguments=[])
    );
    map_call = CallExpression(
        callee=MemberExpression(
            object=await_call, property=Identifier(name="map"), computed=False
        ),
        arguments=[
            ArrowFunctionExpression(
                params=[Identifier(name="x")],
                body=Identifier(name="x"),
                expression=True,
                async_=False
            )
        ]
    );
    prog = Program(body=[ExpressionStatement(expression=map_call)]);
    js_code = es_to_js(prog);

    # The await MUST be parenthesized when used as a member expression object
    assert "(await fetchData())" in js_code , (
        f"AwaitExpression as MemberExpression object must be parenthesized. Got: {js_code}"
    );
    assert "(await fetchData()).map(" in js_code , (
        f"Expected (await fetchData()).map(...), got: {js_code}"
    );
    # Must NOT have unparenthesized form
    assert "await fetchData().map(" not in js_code , (
        f"BUG: await not parenthesized before .map(). Got: {js_code}"
    );
}

test "list concat in impl file uses array spread not string plus" {
    # BUG: In .impl.jac files, `items = items + [item]` compiles to
    # JS string concatenation `M + [J]` instead of array spread `[...M, J]`
    # or `[...M, ...J]`.
    fixture = "list_concat_impl.cl.jac";
    js_code = compile_fixture_to_js(fixture, FIXTURES);

    # The JS output must NOT contain raw `+` between array expressions
    # (which would be string concatenation in JS).
    # Look for the pattern: variable + [expression] which is the bug
    lines = js_code.split('\n');
    has_raw_plus_array = False;
    for line in lines {
        stripped = line.strip();
        # Detect pattern: something + [something] that isn't in a string
        if '+ [' in stripped and 'items' in stripped.lower() {
            has_raw_plus_array = True;
        }
    }

    # Should use spread syntax [...items, item] or .concat()
    has_spread = "[..." in js_code;
    has_concat = ".concat(" in js_code;
    has_push = ".push(" in js_code;

    assert (has_spread or has_concat or has_push) or not has_raw_plus_array , (
        "List concatenation in impl file must use array spread/concat, " + "not JS `+` operator (which produces string concatenation)"
    );

    assert_balanced_syntax(js_code, fixture);
}

test "private identifier generates hash prefix" {
    import from jaclang.compiler.passes.ecmascript.estree {
        PrivateIdentifier,
        PropertyDefinition,
        ClassBody,
        ClassDeclaration,
        Identifier,
        Program,
        Literal
    }
    # Build a minimal class with a private field: class Foo { #secret = 42; }
    priv_id = PrivateIdentifier(name="secret");
    prop_def = PropertyDefinition(key=priv_id, value=Literal(value=42, raw="42"));
    cls = ClassDeclaration(id=Identifier(name="Foo"), body=ClassBody(body=[prop_def]));
    prog = Program(body=[cls]);

    js_code = es_to_js(prog);
    assert "#secret" in js_code , (
        f"PrivateIdentifier should emit '#secret', got: {js_code}"
    );
    assert "class Foo" in js_code;
}

test "jsx preserves single-space whitespace between adjacent expression children" {
    # BUG: The parser dropped any whitespace-only JSX_TEXT token, including
    # an intentional single space between two `{expr}` children on the same
    # line.  As a result `<div>{count} {("task" ...)} remaining</div>`
    # emitted children `[count, (cond), " remaining"]` instead of
    # `[count, " ", (cond), " remaining"]`, so the rendered DOM showed
    # "3tasks remaining" instead of "3 tasks remaining" (and "1.5lb"
    # instead of "1.5 lb" in the shopping-list code from the AI day
    # planner tutorial).
    #
    # Whitespace that crosses a newline (indent between `}` and the next
    # `{` on a new line) is structural and must still be dropped, matching
    # Babel's JSX text normalization.
    fixture = "jsx_adjacent_expressions_spaces.cl.jac";
    js_code = compile_fixture_to_js(fixture, FIXTURES);

    # First span: same-line `{count} {("task" if ... else "tasks")} remaining`.
    # Children must include a literal " " separator between count and the
    # conditional, AND between the conditional and "remaining".
    assert (
        "[count, \" \", ((count === 1) ? \"task\" : \"tasks\"), \" remaining\"]" in js_code
    ) , (
        "Same-line `{a} {b}` must emit a `\" \"` child between adjacent "
        f"expressions, got:\n{js_code}"
    );

    # Second span: `{amount} {unit}` — two adjacent expressions only.
    assert "[amount, \" \", unit]" in js_code , (
        "Same-line adjacent `{amount} {unit}` must emit a `\" \"` "
        f"separator child, got:\n{js_code}"
    );

    # Third span: newline-separated `{count}\n{unit}` — structural
    # whitespace MUST be dropped, no `" "` child.
    assert "__jacJsx(\"p\", {}, [count, unit])" in js_code , (
        "Newline-separated `{a}\\n{b}` must NOT emit a whitespace child "
        f"(structural whitespace is dropped per Babel rules), got:\n{js_code}"
    );

    assert_balanced_syntax(js_code, fixture);
}

test "is and is not emit identity comparison operators" {
    # BUG: ES_COMPARISON_OPS had no entries for Tok.KW_IS / Tok.KW_ISN, so
    # both `is` and `is not` fell through to the `===` default. `is None`
    # was accidentally correct; `is not None` silently inverted to `===`,
    # causing branches like `if x is not None { ... }` to run only when x
    # *was* None.
    jac_code = "\"\"\"Test is/is not codegen.\"\"\"\n\ncl def check(x: int | None) -> int {\n    if x is None {\n        return 1;\n    }\n    if x is not None {\n        return 2;\n    }\n    return 3;\n}\n";

    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);
        assert "x === null" in js_code , (
            f"`is None` must emit `=== null`, got:\n{js_code}"
        );
        assert "x !== null" in js_code , (
            f"`is not None` must emit `!== null`, got:\n{js_code}"
        );
        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "fstring format spec invokes runtime format helper" {
    # BUG: exit_formatted_value ignored nd.format_spec, so format mini-language
    # specs like `:.2f` were dropped — `f"{x:.2f}"` rendered "8" instead of
    # "8.00". The fix routes formatted values with a spec through the
    # _jac.builtin.format runtime helper, which honors precision, width,
    # alignment, and type specifiers.
    jac_code = "\"\"\"Test f-string format spec.\"\"\"\n\ncl def fmt_price(x: float) -> str {\n    return f\"${x:.2f}\";\n}\n\ncl def fmt_plain(x: float) -> str {\n    return f\"${x}\";\n}\n";

    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);
        assert "_jac.builtin.format(x, \".2f\")" in js_code , (
            "`f\"{x:.2f}\"` must compile to a runtime format() call, "
            f"got:\n{js_code}"
        );
        # Bare `f"{x}"` (no spec) must still emit a plain template
        # interpolation — the runtime call is reserved for spec'd values.
        assert "${x}" in js_code , (
            f"Bare `f\"{{x}}\"` should still use plain `${{x}}`, got:\n{js_code}"
        );
        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "issue 5930 sibling if else branches each get block scoped let" {
    # BUG: when the same local name is declared (e.g. `x: int = 1;`) in both
    # an if-branch and its sibling else-branch, codegen emitted `let x = ...`
    # only in the first branch and a bare `x = ...` in the second. Under
    # strict mode (every ES module) the else-branch threw
    # `ReferenceError: x is not defined`.
    #
    # Root cause: `_is_name_first_definition` is symbol-table based and treats
    # the else-branch occurrence as a non-first definition, so the existing
    # `is_first AND not _is_declared_in_any_scope` predicate downgraded the
    # emit to bare assignment even though the if-branch's block scope had
    # already been popped. The fix drops the `is_first` half of the guard;
    # block-scope membership is the authoritative signal for whether a JS
    # `let` is still in flight.
    jac_code = "\"\"\"Test #5930 sibling block let.\"\"\"\n\ncl def test(mode: bool) -> int {\n    if mode {\n        x: int = 1;\n        x = 2;\n    } else {\n        x: int = 3;\n        x = 4;\n    }\n    return 0;\n}\n";

    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);

        # Both branches must introduce x with `let` — the else-branch is the
        # one that regressed prior to the fix.
        assert "let x = 1" in js_code , (
            f"if-branch must declare `let x = 1`, got:\n{js_code}"
        );
        assert "let x = 3" in js_code , (
            f"else-branch must declare `let x = 3` (#5930), got:\n{js_code}"
        );

        # And follow-up reassignments inside each branch must NOT redeclare.
        # We assert the absence of `let x = 2` / `let x = 4` to lock that in.
        assert "let x = 2" not in js_code , (
            "in-branch reassignment must stay a bare assignment, " f"got:\n{js_code}"
        );
        assert "let x = 4" not in js_code , (
            "in-branch reassignment must stay a bare assignment, " f"got:\n{js_code}"
        );

        # And the emitted JS must actually execute in strict mode without
        # tripping the ReferenceError from the original bug report. We pipe
        # the bundle through node with `"use strict";` prepended and call
        # both branches.
        wrapper = (
            '"use strict";\n' + js_code + "\nif (typeof test !== 'function')" + " { throw new Error('test() not exported'); }" + "\nif (test(true) !== 0 || test(false) !== 0)" + " { throw new Error('branches must return 0'); }" + "\nconsole.log('ok');\n"
        );
        result = subprocess.run(
            ["node", "--input-type=module", "-e", wrapper],
            capture_output=True,
            text=True,
            timeout=30
        );
        assert result.returncode == 0 , (
            "strict-mode node run failed (#5930 regression):\n"
            f"stdout={result.stdout!r}\nstderr={result.stderr!r}\n"
            f"js:\n{js_code}"
        );
        assert "ok" in result.stdout , (
            "node run did not reach the success print:\n"
            f"stdout={result.stdout!r}\nstderr={result.stderr!r}"
        );

        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "sibling block scopes — elif chain each branch gets its own let" {
    # Generalizes #5930: every alternate-branch (elif as well as else) must
    # re-declare a same-named local with `let`, since each is an independent
    # JS lexical block.
    jac_code = "\"\"\"Test elif chain sibling-block lets.\"\"\"\n\ncl def test_elif(mode: int) -> int {\n    if mode == 1 {\n        x: int = 1;\n        x = 2;\n    } elif mode == 2 {\n        x: int = 3;\n        x = 4;\n    } elif mode == 3 {\n        x: int = 5;\n        x = 6;\n    } else {\n        x: int = 7;\n        x = 8;\n    }\n    return 0;\n}\n";

    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);
        for _expected_init in ["let x = 1", "let x = 3", "let x = 5", "let x = 7"] {
            assert _expected_init in js_code , (
                f"elif chain must declare `{_expected_init}` in its own "
                f"branch, got:\n{js_code}"
            );
        }
        # Run under strict mode through node to catch any
        # ReferenceError-shaped regression.
        wrapper = (
            '"use strict";\n' + js_code + "\nif (test_elif(1) !== 0 || test_elif(2) !== 0" + " || test_elif(3) !== 0 || test_elif(99) !== 0)" + " { throw new Error('branches must return 0'); }" + "\nconsole.log('ok');\n"
        );
        result = subprocess.run(
            ["node", "--input-type=module", "-e", wrapper],
            capture_output=True,
            text=True,
            timeout=30
        );
        assert result.returncode == 0 , (
            "strict-mode elif chain run failed:\n"
            f"stderr={result.stderr!r}\njs:\n{js_code}"
        );
        assert "ok" in result.stdout;
        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "walrus in if-condition still hoists its let despite alt-branch scope finalization" {
    # Regression guard for the alt-branch scope-finalization change made
    # alongside #5930. The compound statement's ScopeInfo collects walrus
    # / hoisted declarations during condition processing and is consumed
    # by `_prepend_hoisted(IfStmt, ...)` inside `exit_if_stmt`. Because
    # the if-body's scope is *finalized* (popped from the stack) when
    # entering the else-branch, `_pop_scope` must only pop the stack and
    # leave the `scope_map[IfStmt]` entry alone — otherwise the hoisted
    # `let n;` is lost and the resulting JS leaves `n` undeclared, which
    # is its own strict-mode ReferenceError.
    #
    # Note: the *location* of the hoist (currently inside the if-body)
    # has a pre-existing accuracy issue separate from this PR — `n`
    # should be visible after the if per Python semantics. This test
    # locks in the current behavior so a future correctness fix is a
    # deliberate change, not an accidental regression.
    jac_code = "\"\"\"Test walrus hoist preservation across alt-branch finalization.\"\"\"\n\ncl def check(seed: int) -> int {\n    if (n := seed) > 5 {\n        x: int = 1;\n    } else {\n        x: int = 2;\n    }\n    return 0;\n}\n";

    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);
        # The hoisted `let n;` must survive. Without the split between
        # stack-pop and map-pop in `_pop_scope`, this declaration was
        # silently dropped when the if had an else branch.
        assert "let n" in js_code , (
            "walrus name `n` from the if-condition must still be hoisted "
            "as a `let` declaration when an else branch is present, "
            f"got:\n{js_code}"
        );
        # And both branches must still get their per-branch `let x`
        # (the #5930 sibling-block fix continues to apply).
        assert "let x = 1" in js_code;
        assert "let x = 2" in js_code;
        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}

test "sibling block scopes — try except finally each get their own let" {
    # Same structural bug as #5930 in a different compound statement: the
    # try-body's UniScopeNode covers its body, and the except / finally
    # blocks are AST children of the TryStmt — so the try-body's `let x`
    # would leak into except / finally and downgrade them to bare
    # assignment. Generalized sibling-block fix.
    jac_code = "\"\"\"Test try/except/finally sibling-block lets.\"\"\"\n\ncl def test_try(mode: bool) -> int {\n    try {\n        x: int = 1;\n        x = 2;\n        if mode {\n            raise Exception(\"force-except\");\n        }\n    } except Exception {\n        x: int = 3;\n        x = 4;\n    } finally {\n        x: int = 5;\n        x = 6;\n    }\n    return 0;\n}\n";

    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);
        for _expected_init in ["let x = 1", "let x = 3", "let x = 5"] {
            assert _expected_init in js_code , (
                f"try/except/finally must declare `{_expected_init}` in its "
                f"own block, got:\n{js_code}"
            );
        }
        # Run under strict mode through node to confirm no
        # `ReferenceError: x is not defined` in the except or finally branch.
        wrapper = (
            '"use strict";\n' + js_code + "\nif (test_try(false) !== 0)" + " { throw new Error('no-throw path must return 0'); }" + "\nif (test_try(true) !== 0)" + " { throw new Error('throw path must return 0'); }" + "\nconsole.log('ok');\n"
        );
        result = subprocess.run(
            ["node", "--input-type=module", "-e", wrapper],
            capture_output=True,
            text=True,
            timeout=30
        );
        assert result.returncode == 0 , (
            "strict-mode try/except/finally run failed:\n"
            f"stderr={result.stderr!r}\njs:\n{js_code}"
        );
        assert "ok" in result.stdout;
        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}


test "in/not in on unknown-typed containers matches Python semantics" {
    import json;
    # `opaque()` returns `any`, so the backend cannot statically prove the
    # container types. Membership must still behave like Python: substring
    # search for strings, element search for lists, key search for dicts.
    js_code = compile_fixture_to_js("dynamic_membership.jac", FIXTURES);
    wrapper = js_code + "\nconsole.log(JSON.stringify(membership()));\n";
    result = subprocess.run(
        ["node", "--input-type=module", "-e", wrapper],
        capture_output=True,
        text=True,
        timeout=30
    );
    assert result.returncode == 0 , (
        "dynamic `in` membership crashed in Node "
        "(raw JS `in` rejects string/array operands):\n"
        f"stderr={result.stderr!r}\njs:\n{js_code}"
    );
    got: dict[str, bool] = json.loads(result.stdout.strip());
    expected = {
        "str_hit": True,
        "str_miss": False,
        "str_not_in_hit": True,
        "list_hit": True,
        "list_miss": False,
        "list_index_trap": False,
        "dict_hit": True,
        "dict_miss": False
    };
    for (key, want) in expected.items() {
        assert key in got , f"missing key '{key}' in result {got}";
        assert got[key] == want , (
            f"membership '{key}': got {got[key]!r}, expected {want!r}"
        );
    }
}


test "cl negative indexing counts from the end like Python (#6320)" {
    import json;
    # Python/Jac negative indices count from the end. A raw JS subscript
    # `xs[-1]` is `undefined`, silently producing the wrong value.
    jac_code = """
cl def neg_index() -> dict {
    xs: list[int] = [10, 20, 30];
    s: str = "abc";
    return {
        "list_last": xs[-1],
        "list_second_last": xs[-2],
        "list_first": xs[0],
        "str_last": s[-1]
    };
}
""";
    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);
        # The broken raw form `[(-1)]` must never be emitted.
        assert "[(-1)]" not in js_code , (
            f"negative index must not lower to a raw JS subscript:\n{js_code}"
        );
        wrapper = js_code + "\nconsole.log(JSON.stringify(neg_index()));\n";
        result = subprocess.run(
            ["node", "--input-type=module", "-e", wrapper],
            capture_output=True,
            text=True,
            timeout=30
        );
        assert result.returncode == 0 , (
            "negative-index run crashed in Node:\n"
            f"stderr={result.stderr!r}\njs:\n{js_code}"
        );
        got = json.loads(result.stdout.strip());
        expected = {
            "list_last": 30,
            "list_second_last": 20,
            "list_first": 10,
            "str_last": "c"
        };
        for (key, want) in expected.items() {
            assert got[key] == want , (
                f"neg-index '{key}': got {got[key]!r}, expected {want!r}\n"
                f"js:\n{js_code}"
            );
        }
    } finally {
        os.unlink(temp_path);
    }
}


test "cl collection truthiness matches Python emptiness (#6320)" {
    import json;
    # JS arrays/objects/Sets are always truthy, so empty-collection guards
    # never short-circuit. Boolean contexts on a collection must test
    # emptiness like Python (empty list/dict/set is falsy; str already agrees).
    jac_code = """
cl def truthy_probe() -> dict {
    el: list[int] = [];
    fl: list[int] = [1];
    ed: dict[str, int] = {};
    fd: dict[str, int] = {"a": 1};
    es_: set[int] = set();
    fs_: set[int] = {1};
    em: str = "";
    fm: str = "x";
    r: dict[str, int] = {};
    if el { r["if_el"] = 1; } else { r["if_el"] = 0; }
    if fl { r["if_fl"] = 1; } else { r["if_fl"] = 0; }
    if ed { r["if_ed"] = 1; } else { r["if_ed"] = 0; }
    if fd { r["if_fd"] = 1; } else { r["if_fd"] = 0; }
    if es_ { r["if_es"] = 1; } else { r["if_es"] = 0; }
    if fs_ { r["if_fs"] = 1; } else { r["if_fs"] = 0; }
    if em { r["if_em"] = 1; } else { r["if_em"] = 0; }
    if fm { r["if_fm"] = 1; } else { r["if_fm"] = 0; }
    if not el { r["not_el"] = 1; } else { r["not_el"] = 0; }
    if not fl { r["not_fl"] = 1; } else { r["not_fl"] = 0; }
    or_res: list[int] = el or fl;
    and_res: list[int] = el and fl;
    r["or_len"] = len(or_res);
    r["and_len"] = len(and_res);
    r["tern_el"] = 1 if el else 0;
    r["tern_fl"] = 1 if fl else 0;
    # `and`/`or` used directly as a condition: the helper returns an *operand*
    # (a collection), and the enclosing if/while must apply Python truthiness to
    # it -- a bare `if (and_(...))` would see an empty array/object as truthy.
    if el and fl { r["and_cond_ff"] = 1; } else { r["and_cond_ff"] = 0; }
    if fl and fs_ { r["and_cond_tt"] = 1; } else { r["and_cond_tt"] = 0; }
    if el or ed { r["or_cond_ff"] = 1; } else { r["or_cond_ff"] = 0; }
    if el or fl { r["or_cond_ft"] = 1; } else { r["or_cond_ft"] = 0; }
    return r;
}
""";
    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);
        wrapper = js_code + "\nconsole.log(JSON.stringify(truthy_probe()));\n";
        result = subprocess.run(
            ["node", "--input-type=module", "-e", wrapper],
            capture_output=True,
            text=True,
            timeout=30
        );
        assert result.returncode == 0 , (
            "collection-truthiness run crashed in Node:\n"
            f"stderr={result.stderr!r}\njs:\n{js_code}"
        );
        got = json.loads(result.stdout.strip());
        expected = {
            "if_el": 0,
            "if_fl": 1,
            "if_ed": 0,
            "if_fd": 1,
            "if_es": 0,
            "if_fs": 1,
            "if_em": 0,
            "if_fm": 1,
            "not_el": 1,
            "not_fl": 0,
            "or_len": 1,
            "and_len": 0,
            "tern_el": 0,
            "tern_fl": 1,
            "and_cond_ff": 0,
            "and_cond_tt": 1,
            "or_cond_ff": 0,
            "or_cond_ft": 1
        };
        for (key, want) in expected.items() {
            assert got[key] == want , (
                f"truthiness '{key}': got {got[key]!r}, expected {want!r}\n"
                f"js:\n{js_code}"
            );
        }
    } finally {
        os.unlink(temp_path);
    }
}


test "cl negative-index assignment and while-truthiness match Python (#6320)" {
    import json;
    # Negative-index assignment must write the element counted from the end
    # (raw `xs[-1] = v` would create a bogus "-1" property), and a `while`
    # guard on a collection must drain like Python rather than loop forever.
    jac_code = """
cl def probe() -> dict {
    xs: list[int] = [1, 2, 3];
    xs[-1] = 99;
    xs[0] = 5;
    d: dict[str, int] = {};
    d["k"] = 7;
    drained: int = 0;
    stack: list[int] = [1, 1, 1];
    while stack {
        stack.pop();
        drained = drained + 1;
    }
    return {
        "xs_last": xs[-1],
        "xs_first": xs[0],
        "d_k": d["k"],
        "drained": drained,
        "stack_empty": len(stack)
    };
}
""";
    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);
        # The broken raw negative-write form must not be emitted.
        assert "xs[(-1)] = 99" not in js_code , (
            f"negative-index assignment must not write a raw subscript:\n{js_code}"
        );
        wrapper = js_code + "\nconsole.log(JSON.stringify(probe()));\n";
        result = subprocess.run(
            ["node", "--input-type=module", "-e", wrapper],
            capture_output=True,
            text=True,
            timeout=30
        );
        assert result.returncode == 0 , (
            "negative-write / while-truthiness run crashed in Node:\n"
            f"stderr={result.stderr!r}\njs:\n{js_code}"
        );
        got = json.loads(result.stdout.strip());
        expected = {
            "xs_last": 99,
            "xs_first": 5,
            "d_k": 7,
            "drained": 3,
            "stack_empty": 0
        };
        for (key, want) in expected.items() {
            assert got[key] == want , (
                f"write/while '{key}': got {got[key]!r}, expected {want!r}\n"
                f"js:\n{js_code}"
            );
        }
    } finally {
        os.unlink(temp_path);
    }
}


test "cl subscript on unknown-typed values keeps JS undefined-on-miss (#6320)" {
    import json;
    # A subscript on an `any`-typed value must remain a faithful superset of a
    # raw `obj[i]`: string keys stay plain member access, a missing key/index
    # yields `undefined` (never throws), and only a possibly-negative numeric
    # index is rewritten to count from the end. This guards the jac-client
    # `data["data"]["user_id"]` pattern from regressing to a KeyError throw.
    jac_code = """
cl def probe(resp: any, xs: any) -> dict {
    present: any = resp["user_id"];
    guard: int = 1 if (resp["data"] and resp["data"]["k"]) else 0;
    return {
        "present": present,
        "guard": guard,
        "neg": xs[-1],
        "neg2": xs[-2]
    };
}
""";
    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);
        # String-literal keys must stay raw member access, not route through
        # the runtime helper (which only matters for possibly-negative indices).
        assert '_jac.poly.getitem(resp, "user_id")' not in js_code , (
            f"string-key access must stay a raw subscript:\n{js_code}"
        );
        wrapper = (
            js_code + "\nconst r = probe({user_id: 'u9', data: {}}, [10, 20, 30]);" + "\nconsole.log(JSON.stringify(r));\n"
        );
        result = subprocess.run(
            ["node", "--input-type=module", "-e", wrapper],
            capture_output=True,
            text=True,
            timeout=30
        );
        assert result.returncode == 0 , (
            "unknown-typed subscript run crashed in Node (should never throw):\n"
            f"stderr={result.stderr!r}\njs:\n{js_code}"
        );
        got = json.loads(result.stdout.strip());
        expected = {"present": "u9", "guard": 0, "neg": 30, "neg2": 20};
        for (key, want) in expected.items() {
            assert got[key] == want , (
                f"unknown-subscript '{key}': got {got[key]!r}, expected {want!r}\n"
                f"js:\n{js_code}"
            );
        }
    } finally {
        os.unlink(temp_path);
    }
}


test "isinstance/issubclass against builtin types, user class, and tuples (#6458)" {
    import json;
    # Regression for jaseci-labs/jaseci#6458. `isinstance(x, str)` (and any
    # other builtin-type check, as used by the shadcn `sidebar` component)
    # crashed ES codegen with a bare `IndexError: list index out of range`:
    # the ES pass had no `exit_builtin_type` handler, so the builtin-type
    # argument was dropped and `emit_isinstance` indexed past the end of its
    # arg list.
    js_code = compile_fixture_to_js("isinstance_builtin.cl.jac", FIXTURES);

    # The Python builtin-type name must never leak into the emitted JS as a
    # bare reference to an undefined global (e.g. `value instanceof str`),
    # which would be a ReferenceError at runtime.
    assert "instanceof str" not in js_code , (
        f"builtin type `str` must not lower to a JS `instanceof str`:\n{js_code}"
    );

    # Drive the emitted JS through Node to confirm correct Python semantics
    # (including bool-as-subclass-of-int, tuple-of-types, and issubclass).
    wrapper = (
        js_code + "\nconst cases = [['hi'], [true], [5], [3.14], [[1, 2]], " + "[new Widget({name: 'w'})]];" + "\nconsole.log(JSON.stringify({" + "  classify: cases.map(c => classify(c[0]))," + "  scalar: [is_scalar(5), is_scalar(3.14), is_scalar('x'), " + "is_scalar(true), is_scalar([1])]," + "  subclass: subclass_probe()" + "}));\n"
    );
    result = subprocess.run(
        ["node", "--input-type=module", "-e", wrapper],
        capture_output=True,
        text=True,
        timeout=30
    );
    assert result.returncode == 0 , (
        "isinstance codegen crashed in Node:\n"
        f"stderr={result.stderr!r}\njs:\n{js_code}"
    );
    got = json.loads(result.stdout.strip());
    assert got["classify"] == ["str:hi", "bool", "int", "float", "list", "widget:w"] , (
        f"classify mismatch: {got['classify']}\njs:\n{js_code}"
    );
    assert got["scalar"] == [True, True, True, True, False] , (
        f"is_scalar (tuple-of-types) mismatch: {got['scalar']}\njs:\n{js_code}"
    );
    assert got["subclass"] == [True, True, False, False] , (
        f"issubclass (builtin-tag) mismatch: {got['subclass']}\njs:\n{js_code}"
    );

    assert_balanced_syntax(js_code, "isinstance_builtin.cl.jac");
}

test "builtin name used as a dict key lowers to that key, not the 'key' fallback (#6458)" {
    # Same root cause as the isinstance crash: a Python builtin used as a
    # *value* (here the `type` key of an object literal) produced no es_ast,
    # so `exit_dict_val` fell back to the literal string `'key'` -- silently
    # turning `{type: "email"}` into `{key: "email"}`. JacForm's field
    # renderer read that accidental `config.key`, so once the builtin-type
    # handler started lowering `type` correctly the form input types broke
    # (native `type="email"` validation stopped working). Lock the key down.
    jac_code = "cl def make_cfg() -> dict {\n    return {type: \"email\", label: \"Email\"};\n}\n";

    temp_path = write_temp_jac(jac_code);
    try {
        js_code = compile_fixture_to_js(temp_path);
        assert "\"type\": \"email\"" in js_code or "type: \"email\"" in js_code , (
            f"builtin `type` key must lower to `type`, not the `key` fallback:\n{js_code}"
        );
        assert "key: \"email\"" not in js_code
        and "\"key\": \"email\"" not in js_code , (
            f"builtin `type` key must not collapse to the literal `key`:\n{js_code}"
        );
        assert_balanced_syntax(js_code, temp_path);
    } finally {
        os.unlink(temp_path);
    }
}
