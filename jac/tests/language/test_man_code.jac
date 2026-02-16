"""Manual code execution tests – migrated from test_man_code.py.

Tests that manual code examples compile and execute correctly.
"""

import io;
import sys;
import os;
import from pathlib { Path }
import from contextlib { suppress }
import jaclang;
import from jaclang.cli.commands { analysis, execution, tools }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     EXAMPLES = os.path.join(JAC_ROOT, "examples"),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "circle jac" {
    captured = io.StringIO();
    sys.stdout = captured;
    execution.run(os.path.join(EXAMPLES, "manual_code", "circle.jac"));
    sys.stdout = sys.__stdout__;
    stdout_value = captured.getvalue();
    assert "Area of a circle with radius 5 using function: 78" in stdout_value;
    assert "Area of a Circle with radius 5 using class: 78" in stdout_value;
}

test "circle jac test" {
    captured_output = io.StringIO();
    stdout_block = io.StringIO();
    sys.stderr = captured_output;
    sys.stdout = stdout_block;
    analysis.test(os.path.join(EXAMPLES, "manual_code", "circle.jac"));
    sys.stderr = sys.__stderr__;
    sys.stdout = sys.__stdout__;
    stderr_value = captured_output.getvalue();
    assert "Ran 3 tests" in stderr_value;
}

test "clean circle jac" {
    captured = io.StringIO();
    sys.stdout = captured;
    execution.run(os.path.join(EXAMPLES, "manual_code", "circle_clean.jac"));
    sys.stdout = sys.__stdout__;
    stdout_value = captured.getvalue();
    assert stdout_value == (
        "Area of a circle with radius 5 using function: 78.53981633974483\n"
        "Area of a Circle with radius 5 using class: 78.53981633974483\n"
    );
}

test "pure circle jac" {
    captured = io.StringIO();
    sys.stdout = captured;
    execution.run(os.path.join(EXAMPLES, "manual_code", "circle_pure.jac"));
    sys.stdout = sys.__stdout__;
    stdout_value = captured.getvalue();
    assert stdout_value == (
        "Area of a circle with radius 5 using function: 78.53981633974483\n"
        "Area of a Circle with radius 5 using class: 78.53981633974483\n"
    );
}

test "pure circle impl not double generated" {
    captured = io.StringIO();
    sys.stdout = captured;
    tools.tool(
        "ir", ["py", os.path.join(EXAMPLES, "manual_code", "circle_pure.jac"), ]
    );
    sys.stdout = sys.__stdout__;
    stdout_value = captured.getvalue();
    assert "\ndef __init__(self" not in stdout_value;
}

test "clean circle jac test" {
    captured_output = io.StringIO();
    stdio_block = io.StringIO();
    sys.stderr = captured_output;
    sys.stdout = stdio_block;
    with suppress(SystemExit) {
        analysis.test(os.path.join(EXAMPLES, "manual_code", "circle_clean_tests.jac"));
    }
    sys.stderr = sys.__stderr__;
    sys.stdout = sys.__stdout__;
    stderr_value = captured_output.getvalue();
    assert "Ran 3 tests" in stderr_value;
}

test "pure circle jac test" {
    captured_output = io.StringIO();
    stdio_block = io.StringIO();
    sys.stderr = captured_output;
    sys.stdout = stdio_block;
    with suppress(SystemExit) {
        analysis.test(os.path.join(EXAMPLES, "manual_code", "circle_pure.test.jac"));
    }
    sys.stderr = sys.__stderr__;
    sys.stdout = sys.__stdout__;
    stderr_value = captured_output.getvalue();
    assert "Ran 3 tests" in stderr_value;
}

test "jac name in sys mods" {
    captured = io.StringIO();
    sys.stdout = captured;
    execution.run(os.path.join(FIXTURES, "abc_check.jac"));
    sys.stdout = sys.__stdout__;
    stdout_value = captured.getvalue();
    assert "Area of a circle with radius 5 using function: 78" in stdout_value;
    assert "Area of a Circle with radius 5 using class: 78" in stdout_value;
}
