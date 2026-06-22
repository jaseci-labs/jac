"""Tests for jac0 bootstrapper impl emission."""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.jac0 { compile_jac }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "fixtures");

"""Helper to compile a fixture with its impl file."""
def compile_fixture(name: str) -> str {
    main_src = open(os.path.join(FIXTURES, f"{name}.jac")).read();
    impl_src = open(os.path.join(FIXTURES, f"{name}.impl.jac")).read();
    impl_sources = [(impl_src, f"{name}.impl.jac")];
    return compile_jac(main_src, f"{name}.jac", impl_sources=impl_sources);
}

test "jac0 fullbody with impl does not duplicate" {
    result = compile_fixture("jac0_impl_guard");
    assert result.count("def make") == 1 , "Expected exactly one def make";
    assert result.count("def clone") == 1 , "Expected exactly one def clone";
    assert "ghost_method" not in result , "Orphan ghost_method should not be emitted";
    assert "x = 1" in result , "Stub make should be replaced by impl version";
    assert "self.x + 100" not in result , "Fullbody clone should not be replaced by impl version";
}

"""jac0 parses `static has` (class-level constants) without falling back to jac2py.

Regression: `static has` was routed to _parse_funcdef, which expected `static def`,
causing a ParseError on the type-annotation colon. The fix dispatches `static has`
to _parse_has. This matters for desktop plugin transpilation: jac2py fallback
emits `from jaclang...` imports that the embedded stdlib-only CPython can't load.
"""
test "jac0 parses static has as class-level constants" {
    src = '''
obj ErrorCode {
    static has INVALID_ARGS: str = "INVALID_ARGS",
        FORBIDDEN: str = "FORBIDDEN",
        NOT_FOUND: str = "NOT_FOUND";
}
''';
    result = compile_jac(src, "static_has.jac");
    assert "INVALID_ARGS" in result , "static has field INVALID_ARGS missing";
    assert "FORBIDDEN" in result , "static has field FORBIDDEN missing";
    assert "NOT_FOUND" in result , "static has field NOT_FOUND missing";
    assert "from jaclang" not in result , "jac0 output must not import jaclang";
    assert "import jaclang" not in result , "jac0 output must not import jaclang";
}

"""jac0 still parses `static def` (static methods) after the dispatch fix."""
test "jac0 parses static def after static has fix" {
    src = '''
obj Calculator {
    static has PI: float = 3.14;
    static def circle_area(r: float) -> float {
        return PI * r * r;
    }
}
''';
    result = compile_jac(src, "static_def.jac");
    assert "@staticmethod" in result , "static def must emit @staticmethod";
    assert "def circle_area" in result , "static def circle_area missing";
    assert "PI" in result , "static has PI missing";
}
