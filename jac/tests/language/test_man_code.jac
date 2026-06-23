"""Manual code execution tests – migrated from test_man_code.py.

Tests that manual code examples compile and execute correctly.
"""

import io;
import sys;
import os;
import from tests.support { JAC_ROOT }
import from contextlib { suppress }
import jaclang;
import from jaclang.cli.commands { analysis, execution, tools }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "circle jac" {
    captured = io.StringIO();
    sys.stdout = captured;
    execution.run(os.path.join(FIXTURES, "circle.jac"));
    sys.stdout = sys.__stdout__;
    stdout_value = captured.getvalue();
    assert "Area of a circle with radius 5 using function: 78" in stdout_value;
    assert "Area of a Circle with radius 5 using class: 78" in stdout_value;
}

test "circle jac test" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    # jac test routes through pytest, which reports the run on stdout. Force
    # serial collection (JAC_TEST_JOBS=0): when this test itself runs under
    # `-n auto`, an inherited `auto` would make the in-process run spawn its own
    # xdist pool and print "[3 items]" instead of the serial "collected 3 items".
    prev_jobs = os.environ.get("JAC_TEST_JOBS");
    os.environ["JAC_TEST_JOBS"] = "0";
    try {
        analysis.test(os.path.join(FIXTURES, "circle.jac"));
    } finally {
        if prev_jobs is None {
            del os.environ["JAC_TEST_JOBS"];
        } else {
            os.environ["JAC_TEST_JOBS"] = prev_jobs;
        }
    }
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "collected 3 items" in stdout_value;
}

test "clean circle jac" {
    captured = io.StringIO();
    sys.stdout = captured;
    execution.run(os.path.join(FIXTURES, "circle_clean.jac"));
    sys.stdout = sys.__stdout__;
    stdout_value = captured.getvalue();
    assert "Area of a circle with radius 5 using function: 78.53981633974483" in stdout_value;
    assert "Area of a Circle with radius 5 using class: 78.53981633974483" in stdout_value;
}

test "pure circle jac" {
    captured = io.StringIO();
    sys.stdout = captured;
    execution.run(os.path.join(FIXTURES, "circle_pure.jac"));
    sys.stdout = sys.__stdout__;
    stdout_value = captured.getvalue();
    assert "Area of a circle with radius 5 using function: 78.53981633974483" in stdout_value;
    assert "Area of a Circle with radius 5 using class: 78.53981633974483" in stdout_value;
}

test "pure circle impl not double generated" {
    captured = io.StringIO();
    sys.stdout = captured;
    tools.tool("ir", ["py", os.path.join(FIXTURES, "circle_pure.jac"), ]);
    sys.stdout = sys.__stdout__;
    stdout_value = captured.getvalue();
    assert "\ndef __init__(self" not in stdout_value;
}

test "clean circle jac test" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    # Force serial so the nested run prints "collected 3 items" (see above).
    prev_jobs = os.environ.get("JAC_TEST_JOBS");
    os.environ["JAC_TEST_JOBS"] = "0";
    try {
        with suppress(SystemExit) {
            analysis.test(os.path.join(FIXTURES, "circle_clean_tests.jac"));
        }
    } finally {
        if prev_jobs is None {
            del os.environ["JAC_TEST_JOBS"];
        } else {
            os.environ["JAC_TEST_JOBS"] = prev_jobs;
        }
    }
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "collected 3 items" in stdout_value;
}

test "pure circle jac test" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    # Force serial so the nested run prints "collected 3 items" (see above).
    prev_jobs = os.environ.get("JAC_TEST_JOBS");
    os.environ["JAC_TEST_JOBS"] = "0";
    try {
        with suppress(SystemExit) {
            analysis.test(os.path.join(FIXTURES, "circle_pure.test.jac"));
        }
    } finally {
        if prev_jobs is None {
            del os.environ["JAC_TEST_JOBS"];
        } else {
            os.environ["JAC_TEST_JOBS"] = prev_jobs;
        }
    }
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "collected 3 items" in stdout_value;
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
