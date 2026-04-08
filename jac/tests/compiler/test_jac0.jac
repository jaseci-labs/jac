"""Tests for jac0 bootstrapper impl emission."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0 { compile_jac }

glob FIXTURES = os.path.join(
    str(Path(jaclang.__file__).parent.parent), "tests", "compiler", "fixtures"
);

"""Helper to compile a fixture with its impl file."""
def compile_fixture(name: str, has_impl: bool = True) -> str {
    main_src = open(os.path.join(FIXTURES, f"{name}.jac")).read();
    impl_sources = None;
    if has_impl {
        impl_src = open(os.path.join(FIXTURES, f"{name}.impl.jac")).read();
        impl_sources = [(impl_src, f"{name}.impl.jac")];
    }
    return compile_jac(main_src, f"{name}.jac", impl_sources=impl_sources);
}

test "jac0 stub with impl emits single method" {
    result = compile_fixture("jac0_scenario1_stub_impl");
    assert result.count("def make") == 1 , "Expected exactly one def make";
    assert result.count("def clone") == 1 , "Expected exactly one def clone";
}

test "jac0 fullbody with impl does not duplicate" {
    result = compile_fixture("jac0_scenario2_fullbody_impl");
    assert result.count("def make") == 1 , "Expected exactly one def make";
    assert result.count("def clone") == 1 , "Expected exactly one def clone";
    assert "non_decl_func" not in result , "Orphan non_decl_func should not be emitted";
}

test "jac0 orphan impl is not emitted" {
    result = compile_fixture("jac0_scenario3_nodecl_impl");
    assert "ghost_method" not in result , "Orphan ghost_method should not be emitted";
    assert result.count("def make") == 1 , "Expected exactly one def make";
}

test "jac0 fullbody without impl emits normally" {
    result = compile_fixture("jac0_scenario4_fullbody_noimpl", has_impl=False);
    assert result.count("def make") == 1 , "Expected exactly one def make";
    assert result.count("def clone") == 1 , "Expected exactly one def clone";
}
