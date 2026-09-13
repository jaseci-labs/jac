import from jaclang.compiler.native_scope { NATIVE_SCOPE, NativeScopeEntry }
import from jaclang.compiler.driver.image { _jaclang_image }

test "the running image records its native kernel and layout as verified payloads" {
    image = _jaclang_image();
    assert image is not None;
    kernels = [
        path
        for path in image.payloads
        if path.startswith("compiler/libjac_compiler.") and not path.endswith(".json")
    ];
    assert len(kernels) == 1;
    assert kernels[0] + ".layout.json" in image.payloads;
    image.verify();
}

test "every scope entry is a jaclang module with a default-off strict flag" {
    for e in NATIVE_SCOPE {
        assert isinstance(e, NativeScopeEntry);
        assert e.module.startswith("jaclang.") , e.module;
        assert isinstance(e.strict, bool);
    }
}
