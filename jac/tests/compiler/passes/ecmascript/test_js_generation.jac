"""Test JavaScript code generation using consolidated Jac fixtures.

Migrated from test_js_generation.py to native Jac test format.
"""

import os;
import subprocess;
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
     LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

def compile_fixture_to_js(fixture_name: str, fixture_dir: str = "") -> str {
    """Compile a Jac fixture to JavaScript and return the emitted source."""
    fixture_path = fixture_name;
    if not Path(fixture_path).exists() and fixture_dir {
        fixture_path = os.path.join(fixture_dir, fixture_name);
    }
    prog = JacProgram();
    ir = prog.compile(file_path=fixture_path, no_cgen=True);

    assert not prog.errors_had , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    );

    es_pass = EsastGenPass(ir, prog);
    es_ir = es_pass.ir_out;

    assert hasattr(es_ir.gen, "es_ast") , "es_ast attribute missing";
    es_ast = es_ir.gen.es_ast;
    assert isinstance(es_ast, EsNode) , "es_ast should be an EsNode";

    return es_to_js(es_ast);
}

def assert_balanced_syntax(js_code: str, fixture_name: str) -> None {
    """Ensure generated JavaScript has balanced delimiters."""
    pairs = [("{", "}"), ("(", ")"), ("[", "]")];
    for (open_char, close_char) in pairs {
        assert js_code.count(open_char) == js_code.count(close_char) , (
            f"{fixture_name} produced unbalanced {open_char}{close_char} pairs"
        );
    }
}

def assert_no_jac_keywords(js_code: str, fixture_name: str) -> None {
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

    ];

    for kw in jac_keywords {
        assert kw not in js_code , (
            f"Jac keyword '{kw.strip()}' leaked into JavaScript for {fixture_name}"
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
    for pattern in ["try", "catch (err)", "finally"] {
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
        ["python3", "-m", "jaclang.cli.cli", "js", fixture_file_path],
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
        ["python3", "-m", "jaclang.cli.cli", "js", fixture_file_path, ],
        capture_output=True,
        text=True,
        env=env,
    );

    assert result.returncode == 0 , (
        f"CLI failed to compile cl only file: {result.stderr}"
    );
    assert len(result.stdout) > 0;
    assert "function greet(name) {" in result.stdout;
}

test "empty file generates minimal js" {
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp {
        tmp.write("\"\"\"Empty file for smoke testing.\"\"\"\n");
        temp_path = tmp.name;
    }

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

    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp {
        tmp.write(jac_code);
        tmp.flush();
        temp_path = tmp.name;
    }

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

    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp {
        tmp.write(jac_code);
        tmp.flush();
        temp_path = tmp.name;
    }

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

    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp {
        tmp.write(jac_code);
        tmp.flush();
        temp_path = tmp.name;
    }

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

    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp {
        tmp.write(jac_code);
        tmp.flush();
        temp_path = tmp.name;
    }

    try {
        js_code = compile_fixture_to_js(temp_path);

        for pattern in ["function calculate_message", "function conditional_message", ] {
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
    for pattern in ["${", "${user}", "${score}", "${status}", "scored", "which is a", ] {
        assert pattern in js_code;
    }
}

test "fstring edge cases" {
    jac_code = "\"\"\"Test f-string edge cases.\"\"\"\n\ncl def test_edge_cases() -> dict {\n    name = \"Alice\";\n    value = 42;\n\n    # Text only (no interpolation)\n    text_only = f\"This is just plain text\";\n\n    # Expression only (no static text)\n    expr_only = f\"{value}\";\n\n    # Multiple consecutive expressions\n    consecutive = f\"{name}{value}\";\n\n    # Mixed with spaces\n    mixed = f\"Name: {name}, Value: {value}\";\n\n    return {\"text\": text_only, \"expr\": expr_only, \"cons\": consecutive, \"mixed\": mixed};\n}\n";

    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp {
        tmp.write(jac_code);
        tmp.flush();
        temp_path = tmp.name;
    }

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

    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp {
        tmp.write(jac_code);
        tmp.flush();
        temp_path = tmp.name;
    }

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
    assert "__jacSpawn(\"create_todo\", \"\", {\"text\": input.strip()});" in js_code;
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
        f"Unescaped double-double quotes found in generated JS — "
        f"quote characters in JSX text are being double-wrapped:\n{js_code}"
    );

    # The text content should appear in the output with escaped quotes.
    assert "Try: show all to reset" in js_code , (
        "JSX text content with quotes should appear in output"
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
