"""Tests requiring Python-only infrastructure.

Covers py2jac conversion (PyastBuildPass), tempfile, subprocess,
sys.stderr redirect, os.chdir, xfail, etc.  All simple "run fixture
and check stdout" tests live in test_language.jac.
"""

import ast as py_ast;
import io;
import os;
import subprocess;
import sys;
import tempfile;
import shutil;
import importlib;
import pytest;
import from pathlib { Path }
import from unittest.mock { patch }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang { JacRuntime as Jac }
import from jaclang.cli.commands { execution, transform }
import from jaclang.jac0core.bccache { get_global_cache_dir }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.main { PyastBuildPass }
import from jaclang.runtimelib.utils { read_file_with_encoding }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures"),
     EXAMPLES = os.path.join(JAC_ROOT, "examples");

# Helper function to create files within tests
def create_temp_jac_file(
    content: str, dir_path: str, filename: str = "test_mod.jac"
) -> str {
    """Create a temporary Jac file in a specific directory."""
    full_path = os.path.join(dir_path, filename);
    os.makedirs(os.path.dirname(full_path), exist_ok=True);
    with open(full_path, "w") as f {
        f.write(content);
    }
    return full_path;
}

# -- PyastBuildPass / py2jac tests --
test "pyfunc 1" {
    Jac.attach_program(JacProgram());
    py_out_path = os.path.join(FIXTURES, "pyfunc_1.py");
    with open(py_out_path) as f {
        file_source = f.read();
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path)
            ),
            prog=JacProgram()
        ).ir_out.unparse();
    }
    assert "def greet2(**kwargs: Any) -> None {" in output;
    assert output.count("with entry {") == 14;
    assert "assert (x == 5) , 'x should be equal to 5';" in output;
    assert "if not (x == y) {" in output;
    assert "squares_dict = {x: (x ** 2) for x in numbers};" in output;
    assert '\n"""Say hello"""\n@my_decorator\n\n def say_hello() -> object {' in output;
}

test "pyfunc 2" {
    Jac.attach_program(JacProgram());
    py_out_path = os.path.join(FIXTURES, "pyfunc_2.py");
    with open(py_out_path) as f {
        file_source = f.read();
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path)
            ),
            prog=JacProgram()
        ).ir_out.unparse();
    }
    assert "class X {\n    with entry {\n        a_b = 67;" in output;
    assert "br = b'Hello\\\\\\\\nWorld'" in output;
    assert "class Circle {\n    def init(self: Circle, radius: float" in output;
    assert "`node = 90;\n    print(`node);\n" in output;
}

test "pyfunc 3" {
    Jac.attach_program(JacProgram());
    py_out_path = os.path.join(FIXTURES, "pyfunc_3.py");
    with open(py_out_path) as f {
        file_source = f.read();
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path)
            ),
            prog=JacProgram()
        ).ir_out.unparse();
    }
    assert "if (0 <= x <= 5) {" in output;
    assert "  case _:\n" in output;
    assert " case Point(x = int(a), y = 0):\n" in output;
    assert "class Sample {\n    def init" in output;
}

test "py2jac" {
    Jac.attach_program(JacProgram());
    py_out_path = os.path.join(FIXTURES, "py2jac.py");
    with open(py_out_path) as f {
        file_source = f.read();
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path)
            ),
            prog=JacProgram()
        ).ir_out.unparse();
    }
    assert "match Container(inner=Inner(x=a, y=b)) {\n" in output;
    assert "case Container(inner = Inner(x = a, y = 0)):\n" in output;
    assert "case Container(inner = Inner(x = a, y = b)):\n" in output;
    assert "case _:\n" in output;
}

test "py2jac params" {
    Jac.attach_program(JacProgram());
    py_out_path = os.path.join(FIXTURES, "py2jac_params.py");
    with open(py_out_path) as f {
        file_source = f.read();
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path)
            ),
            prog=JacProgram()
        ).ir_out.unparse();
    }
    assert (
        "def isinstance(`obj: object, class_or_tuple: _ClassInfo, /) -> bool {" in output
    );
    assert (
        "def len(`obj: Sized, astt: object, /, z: int, j: str, a: int = 90) -> int {" in output
    );
}

test "py2jac empty file" {
    Jac.attach_program(JacProgram());
    py_out_path = os.path.join(FIXTURES, "py2jac_empty.py");
    with open(py_out_path) as f {
        file_source = f.read();
        converted_ast = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path)
            ),
            prog=JacProgram()
        ).ir_out;
    }
    assert isinstance(converted_ast, uni.Module);
}

test "py2jac augassign and doc" {
    Jac.attach_program(JacProgram());
    py_out_path = os.path.join(FIXTURES, "py2jac_augassign_doc.py");
    with open(py_out_path) as f {
        file_source = f.read();
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path)
            ),
            prog=JacProgram()
        ).ir_out.unparse();
    }
    assert "x += 2;" in output;
    assert '"""inner doc"""; def inner()' in output;
}

test "py2jac reassign semantics" {
    Jac.attach_program(JacProgram());
    py_out_path = os.path.join(FIXTURES, "py2jac_reassign.py");
    with open(py_out_path) as f {
        file_source = f.read();
        jac_code = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path)
            ),
            prog=JacProgram()
        ).ir_out.unparse();
    }

    # Key check: reassignments should NOT use 'let'
    assert "let found = True" not in jac_code , (
        "py2jac bug: 'let' used for reassignment in loop - "
        "this creates a shadowed variable instead of reassigning"
    );
    assert (
        "let status = " not in jac_code.split("let status = ")[2]
        if jac_code.count("let status = ") > 1
        else True
    ) , "py2jac bug: 'let' used for reassignment in conditional";

    # Execute the converted code and verify it produces correct results
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        Jac.jac_import(target="py2jac_reassign", base_path=FIXTURES);
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "All tests passed!" in stdout_value , (
        f"Converted Jac code produced wrong output. "
        f"This likely means py2jac created shadowed variables. Output: {stdout_value}"
    );
}

test "py namedexpr" {
    Jac.attach_program(JacProgram());
    py_out_path = os.path.join(FIXTURES, "py_namedexpr.py");
    with open(py_out_path) as f {
        file_source = f.read();
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path)
            ),
            prog=JacProgram()
        ).ir_out.unparse();
    }
    assert "(x := 10)" in output;
}

test "py bool parentheses" {
    Jac.attach_program(JacProgram());
    py_out_path = os.path.join(FIXTURES, "py_bool_expr.py");
    with open(py_out_path) as f {
        file_source = f.read();
        output = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=uni.Source(file_source, py_out_path)
            ),
            prog=JacProgram()
        ).ir_out.unparse();
    }
    assert "(prev_token_index is None)" in output;
    assert "(next_token_index is None)" in output;
    assert "(tok[0] > change_end_line)" in output;
    assert "(tok[0] == change_end_line)" in output;
    assert "(tok[1] > change_end_char)" in output;
}

test "funccall genexpr py2jac" {
    Jac.attach_program(JacProgram());
    py_file_path = os.path.join(FIXTURES, "funccall_genexpr.py");
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        transform.py2jac(py_file_path);
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "result = total((x * x) for x in range(5));" in stdout_value;
}

# -- Tests requiring special Python infrastructure --
test "deep imports interp mode" {
    Jac.set_base_path(FIXTURES);
    Jac.attach_program(JacProgram());
    # Clear any cached module from previous test runs
    for mod_name in list(sys.modules.keys()) {
        if "deep_import_interp" in mod_name {
            del sys.modules[mod_name];
        }
    }
    # Delete bytecode cache files to force recompilation (from global cache dir)
    cache_dir = get_global_cache_dir();
    if cache_dir.exists() {
        for cache_file in cache_dir.glob("*deep_import*") {
            cache_file.unlink();
        }
    }

    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        Jac.jac_import("deep_import_interp", base_path=FIXTURES);
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    # Main module must be registered in the hub; transitive imports may also
    # appear when their bytecode isn't cached yet, so only assert presence.
    assert os.path.join(FIXTURES, "deep_import_interp.jac") in Jac.get_program().mod.hub;
    assert "one level deeperslHello World!" in stdout_value;

    Jac.set_base_path(FIXTURES);
    Jac.attach_program((prog := JacProgram()));
    prog.compile(os.path.join(FIXTURES, "deep_import_interp.jac"));
    # as we use jac_import, only main module should be in the hub
    assert len(Jac.get_program().mod.hub.keys()) == 1;
}

test "deep outer imports from loc" {
    Jac.attach_program(JacProgram());
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        original_cwd = os.getcwd();
        os.chdir(os.path.join(FIXTURES, "deep", "deeper"));
        try {
            execution.run("deep_outer_import.jac");
        } finally {
            os.chdir(original_cwd);
        }
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    assert "one level deeperslHello World!" in stdout_value;
    assert (
        "module 'jaclang.tests.fixtures.pyfunc' from " in stdout_value
        or "module 'pyfunc' from " in stdout_value
    );
}

test "inherit baseclass sym" {
    pytest.xfail("TODO: Support symtable for inheritance");
    mypass = JacProgram().compile(
        os.path.join(EXAMPLES, "guess_game", "guess_game3.jac")
    );
    table = None;
    for i in mypass.sym_tab.kid_scope {
        if i.scope_name == "GuessTheNumberGame" {
            for j in i.kid_scope {
                if j.scope_name == "play" {
                    table = j;
                    break;
                }
            }
            break;
        }
    }
    assert table is not None;
    assert table.lookup("attempts") is not None;
}

test "list methods" {
    Jac.set_base_path(FIXTURES);
    Jac.attach_program(JacProgram());
    sys.modules.pop("foo", None);
    sys.modules.pop("bar", None);
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        Jac.jac_import("foo", base_path=FIXTURES);
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();

    assert "Module: foo" in stdout_value;
    assert "Module: bar" in stdout_value;
    assert "Walkers in bar:\n  - Walker: bar_walk" in stdout_value;
    assert "Nodes in bar:\n  - Node: Item" in stdout_value;
    assert "Edges in bar:\n  - Edge: Link" in stdout_value;
    assert "Item value: 0" in stdout_value;
    assert "Created 5 items." in stdout_value;
}

test "walker dynamic update" {
    _tmpdir = tempfile.mkdtemp();
    Jac.set_base_path(_tmpdir);
    Jac.attach_program(JacProgram());
    sys.modules.pop("bar", None);
    bar_file_path = os.path.join(FIXTURES, "bar.jac");
    update_file_path = os.path.join(FIXTURES, "walker_update.jac");
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        execution.enter(filename=bar_file_path, entrypoint="bar_walk", args=[]);
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured.getvalue();
    expected_output = "Created 5 items.";
    assert expected_output in stdout_value.split("\n");
    # Define the new behavior to be added (using entry since exits are deferred
    # and won't run when disengage is called during child traversal)
    new_behavior = """
    # New behavior added during runtime
    can announce with Root entry {
        "bar_walk has been updated with new behavior!" |> print;
        }
    }
    """;

    # Backup the original file content
    with open(bar_file_path) as bar_file {
        original_content = bar_file.read();
    }

    # Update the bar.jac file with new behavior
    with open(bar_file_path, "r+") as bar_file {
        content = bar_file.read();
        last_brace_index = content.rfind("}");
        if last_brace_index != -1 {
            updated_content = content[:last_brace_index] + new_behavior;
            bar_file.seek(0);
            bar_file.write(updated_content);
            bar_file.truncate();
        }
    }

    captured2 = io.StringIO();
    old_stdout2 = sys.stdout;
    sys.stdout = captured2;
    try {
        # Reset state for dynamic update test
        Jac.loaded_modules.clear();
        Jac.attach_program(JacProgram());
        execution.run(filename=update_file_path);
        stdout_value2 = captured2.getvalue();
        expected_output2 = "bar_walk has been updated with new behavior!";
        assert expected_output2 in stdout_value2.split("\n");
    } finally {
        sys.stdout = old_stdout2;
        # Restore the original content of bar.jac
        with open(bar_file_path, "w") as bar_file {
            bar_file.write(original_content);
        }
        shutil.rmtree(_tmpdir, ignore_errors=True);
    }
}

test "import from site packages" {
    Jac.attach_program(JacProgram());
    with tempfile.TemporaryDirectory() as tmpdir {
        # Simulate site-packages directory structure
        mock_site_dir = os.path.join(tmpdir, "site-packages");
        os.makedirs(mock_site_dir);
        # Create a module within the simulated site-packages
        site_mod_content = 'with entry { "Site package module loaded!" |> print; }';
        create_temp_jac_file(site_mod_content, mock_site_dir, "site_pkg_mod.jac");
        # Create the importing script in the main temp directory
        importer_content = "import site_pkg_mod;";
        _ = create_temp_jac_file(importer_content, tmpdir, "importer_site.jac");
        with patch("site.getsitepackages", return_value=[mock_site_dir]) {
            captured = io.StringIO();
            old_stdout = sys.stdout;
            sys.stdout = captured;
            original_cwd = os.getcwd();
            try {
                Jac.jac_import("importer_site", base_path=tmpdir);
            } finally {
                os.chdir(original_cwd);
                sys.stdout = old_stdout;
            }
            stdout_value = captured.getvalue();
            assert "Site package module loaded!" in stdout_value;
        }
    }
}

test "import from jacpath" {
    Jac.attach_program(JacProgram());
    with tempfile.TemporaryDirectory() as tmpdir {
        # Simulate JACPATH directory
        jacpath_dir = os.path.join(tmpdir, "jaclibs");
        os.makedirs(jacpath_dir);
        # Create a module in the JACPATH directory
        jacpath_mod_content = 'with entry { "JACPATH module loaded!" |> print; }';
        create_temp_jac_file(jacpath_mod_content, jacpath_dir, "jacpath_mod.jac");
        # Create the importing script in a different location
        script_dir = os.path.join(tmpdir, "scripts");
        os.makedirs(script_dir);
        importer_content = "import jacpath_mod;";
        _ = create_temp_jac_file(importer_content, script_dir, "importer.jac");
        # Set JACPATH environment variable and run
        original_jacpath = os.environ.get("JACPATH");
        os.environ["JACPATH"] = jacpath_dir;
        captured = io.StringIO();
        old_stdout = sys.stdout;
        sys.stdout = captured;
        original_cwd = os.getcwd();
        os.chdir(script_dir);
        try {
            execution.run("importer.jac");
        } finally {
            os.chdir(original_cwd);
            sys.stdout = old_stdout;
            # Clean up environment variable
            if original_jacpath is None {
                if "JACPATH" in os.environ {
                    del os.environ["JACPATH"];
                }
            } else {
                os.environ["JACPATH"] = original_jacpath;
            }
        }
        stdout_value = captured.getvalue();
        assert "JACPATH module loaded!" in stdout_value;
    }
}

test "import jac from py" {
    Jac.attach_program(JacProgram());
    captured = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured;
    try {
        jac_from_py_mod = importlib.import_module(
            "tests.language.fixtures.jac_from_py"
        );
        jac_from_py_mod.main();
    } finally {
        sys.stdout = old_stdout;
    }

    stdout_value = captured.getvalue();
    assert (
        stdout_value == "Value: -1\nValue: 0\nValue: 1\nValue: 2\nValue: 3\nValue: 4"
        "\nValue: 5\nValue: 6\nValue: 7\nFinal Value: 8\nDone walking.\n"
    );
}

test "here visitor error" {
    Jac.attach_program(JacProgram());
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    sys.stderr = captured_output;
    try {
        result = execution.run(os.path.join(FIXTURES, "here_usage_error.jac"));
    } finally {
        sys.stdout = sys.__stdout__;
        sys.stderr = sys.__stderr__;
    }
    assert result == 1;
    stdout_value = captured_output.getvalue();
    assert "'here' is not defined" in stdout_value;
}

test "by operator" {
    Jac.attach_program(JacProgram());
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    sys.stderr = captured_output;
    try {
        result = execution.run(os.path.join(FIXTURES, "by_operator.jac"));
    } finally {
        sys.stdout = sys.__stdout__;
        sys.stderr = sys.__stderr__;
    }
    assert result == 1;
    stdout_value = captured_output.getvalue();
    assert "by" in stdout_value.lower();
    assert "not" in stdout_value.lower();
    assert "implemented" in stdout_value.lower();
}

test "sitecustomize meta importer" {
    Jac.attach_program(JacProgram());
    with tempfile.TemporaryDirectory() as tmpdir {
        Path(tmpdir, "mymod.jac").write_text('with entry {print("via meta");}');
        env = os.environ.copy();
        project_root = str(Path(JAC_ROOT));
        env["PYTHONPATH"] = os.pathsep.join([project_root, tmpdir]);
        proc = subprocess.run(
            [sys.executable, "-c", "import mymod"],
            capture_output=True,
            text=True,
            cwd=tmpdir,
            env=env
        );
        assert proc.returncode == 0 , proc.stderr;
        assert proc.stdout.strip() == "via meta";
    }
}

# -- read_file_with_encoding tests --
test "read file with encoding utf8" {
    Jac.attach_program(JacProgram());
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", delete=False) as f {
        test_content = "Hello, \u4e16\u754c! \U0001f30d Testing UTF-8 encoding.";
        f.write(test_content);
        temp_path = f.name;
    }

    try {
        result = read_file_with_encoding(temp_path);
        assert result == test_content;
    } finally {
        os.unlink(temp_path);
    }
}

test "read file with encoding utf16" {
    Jac.attach_program(JacProgram());
    with tempfile.NamedTemporaryFile(delete=False, mode="w", encoding="utf-16") as f {
        test_content = "Hello, \u4e16\u754c! UTF-16 encoding test.";
        f.write(test_content);
        temp_path = f.name;
    }

    try {
        result = read_file_with_encoding(temp_path);
        assert result == test_content;
    } finally {
        os.unlink(temp_path);
    }
}

test "read file with encoding utf8 bom" {
    Jac.attach_program(JacProgram());
    with tempfile.NamedTemporaryFile(delete=False, mode="w", encoding="utf-8-sig") as f {
        test_content = "Hello, UTF-8 BOM test! \U0001f680";
        f.write(test_content);
        temp_path = f.name;
    }

    try {
        result = read_file_with_encoding(temp_path);
        assert result == test_content;
    } finally {
        os.unlink(temp_path);
    }
}

test "read file with encoding binary file fallback" {
    Jac.attach_program(JacProgram());
    with tempfile.NamedTemporaryFile(delete=False) as f {
        binary_data = bytes([0xFF, 0xFE, 0x00, 0x48, 0x65, 0x6C, 0x6C, 0x6F]);
        f.write(binary_data);
        f.flush();
        temp_path = f.name;
    }

    try {
        result = read_file_with_encoding(temp_path);
        assert isinstance(result, str);
        assert len(result) > 0;
    } finally {
        os.unlink(temp_path);
    }
}

test "read file with encoding special characters" {
    Jac.attach_program(JacProgram());
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", delete=False) as f {
        test_content = "Special chars: \u00e5\u00e4\u00f6 \u00f1 \u00fc \u00e7 \u00e9\nSymbols: \u00a9\u00ae\u2122 \u00a7\u00b6\u2020\u2021\u2022\nMath: \u2211\u220f\u222b\u221a\u00b1\u2264\u2265\u2260\nArrows: \u2190\u2192\u2191\u2193\u2194\nEmoji: \U0001f600\U0001f60d\U0001f389\U0001f525\U0001f4af\n";
        f.write(test_content);
        f.flush();
        temp_path = f.name;
    }

    try {
        result = read_file_with_encoding(temp_path);

        assert result == test_content;
        assert "\u00e5\u00e4\u00f6" in result;
        assert "\u00a9\u00ae\u2122" in result;
        assert "\u2211\u220f\u222b" in result;
        assert "\U0001f600\U0001f60d" in result;
    } finally {
        os.unlink(temp_path);
    }
}
