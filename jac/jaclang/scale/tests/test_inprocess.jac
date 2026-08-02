import from jaclang.jac0core.ext_registry { base_stem }


# base_stem strips annex suffixes (.impl, .test) from .jac module filenames.
# Retired codespace markers (.sv.jac, .na.jac, .cl.jac) are no longer stripped
# after #7772/#7773; placement is inferred, not spelled in filenames.
test "module stem strips annex suffixes from jac filenames" {
    assert base_stem("/app/main.impl.jac") == "main";
    assert base_stem("/app/main.test.jac") == "main";
    assert base_stem("/app/main.jac") == "main";
}
