"""Tests for jac0 bootstrapper impl emission."""

import ast;
import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0 { compile_jac }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent), "tests", "compiler", "fixtures"
     );

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

"""Empty match body must compile to valid Python (no `match X:` with zero cases)."""
test "jac0 empty match body emits valid Python" {
    src = "def go {\n    match x {}\n}";
    result = compile_jac(src, "empty_match.jac");
    ast.parse(result);
    assert "match x:" not in result , "Empty match must not emit a bare match header";
}

"""Empty switch body must compile to valid Python (and preserve subject side effects)."""
test "jac0 empty switch body emits valid Python" {
    src = "def go {\n    switch x {}\n}";
    result = compile_jac(src, "empty_switch.jac");
    ast.parse(result);
    assert "if " not in result and "elif " not in result and "else:" not in result , "Empty switch must not emit any if/elif/else chain";
}

"""switch { default: ... } alone must not emit `else:` with no preceding `if`."""
test "jac0 switch with only default emits valid Python" {
    src = "def go {\n    switch x { default: y = 1; }\n}";
    result = compile_jac(src, "default_only.jac");
    ast.parse(result);
    assert "else:" not in result , "switch-with-only-default must not emit a bare else";
    assert "y = 1" in result , "Default body must still be emitted";
}

"""`default:` declared before value cases must be emitted at the end of the if/elif/else chain."""
test "jac0 switch with default-first reorders default to end" {
    src = "def go {\n    switch x { default: y = 0; case 1: y = 1; }\n}";
    result = compile_jac(src, "default_first.jac");
    ast.parse(result);
    if_pos = result.find("if (x) == (1):");
    else_pos = result.find("else:");
    assert if_pos != -1 , "Value case must be emitted as `if`";
    assert else_pos != -1 , "Default must be emitted as `else`";
    assert if_pos < else_pos , "Default must come after the value case in the chain";
}
