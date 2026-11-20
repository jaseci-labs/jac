"""base_stem strips annex suffixes from a module path and keeps codespace markers."""

import from jaclang.jac0core.ext_registry { base_stem }


test "module stem strips annex suffixes but keeps retired codespace markers" {
    assert base_stem("/app/main.impl.jac") == "main";
    assert base_stem("/app/main.test.jac") == "main";
    assert base_stem("/app/main.impl.test.jac") == "main";
    assert base_stem("/app/main.jac") == "main";
    assert base_stem("/app/main.sv.jac") == "main.sv";
    assert base_stem("/app/main.cl.jac") == "main.cl";
}
