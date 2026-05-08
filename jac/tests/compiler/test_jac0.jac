"""Tests for jac0 bootstrapper impl emission."""

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
