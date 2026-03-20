"""Shared test infrastructure for type checker tests.

This module provides a shared JacProgram with a cached TypeEvaluator to avoid
the expensive TypeEvaluator initialization (~200-500ms) on every test.

Usage in .jac files:
    import from jaclang.compiler.passes.main.checker_test_utils {
        get_test_program,
        assert_error_pretty_found,
        FIXTURES,
        CHECKER_FIXTURES,
        LANG_FIXTURES,
        NO_TC
    }
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob JAC_ROOT: str = str(Path(jaclang.__file__).parent.parent);
glob FIXTURES: str = os.path.join(JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures");
glob CHECKER_FIXTURES: str = os.path.join(JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "checker");
glob LANG_FIXTURES: str = os.path.join(JAC_ROOT, "tests", "language", "fixtures");
glob NO_TC: CompileOptions = CompileOptions(type_check=False);

glob _shared_program: JacProgram | None = None;

"""Get a test program with shared TypeEvaluator.

The TypeEvaluator is initialized once and reused across all tests,
saving ~200-500ms per test. The module hub is cleared between tests
to ensure fresh compilation without AST mutation issues.
"""
def get_test_program -> JacProgram {
    import from jaclang.jac0core.program { JacProgram }
    global _shared_program;
    if _shared_program is None {
        _shared_program = JacProgram();
        # Force TypeEvaluator initialization (expensive - do once)
        _shared_program.get_type_evaluator();
    }

    # Reset state for new test
    _shared_program.errors_had = [];
    _shared_program.warnings_had = [];
    _shared_program.mod.hub.clear();
    _shared_program.mod.main_mod = None;

    # Reset narrowing cache
    if _shared_program.type_evaluator {
        _shared_program.type_evaluator._narrowing_cache = {};
        _shared_program.type_evaluator._narrowing_scope_stack = [];
        _shared_program.type_evaluator._narrowing_in_progress = set();
        _shared_program.type_evaluator._module_type_cache = {};
    }

    return _shared_program;
}

"""Assert that expected error text appears in the actual error output."""
def assert_error_pretty_found(needle: str, haystack: str) -> None {
    for line in [line.strip() for line in needle.splitlines() if line.strip()] {
        assert line in haystack, f"Expected line '{line}' not found in:\n{haystack}";
    }
}
