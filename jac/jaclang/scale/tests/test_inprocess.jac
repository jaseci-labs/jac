import from jaclang.jac0core.ext_registry { base_stem }


test "module stem strips compound codespace suffixes" {
    assert base_stem("/app/main.impl.jac") == "main";
    assert base_stem("/app/main.impl.jac") == "main";
    assert base_stem("/app/main.sv.jac") == "main";
    assert base_stem("/app/main.jac") == "main";
}
