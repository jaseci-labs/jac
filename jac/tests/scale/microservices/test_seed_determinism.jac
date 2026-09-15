import os;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.bundle { pack_jab, content_address }
import from jaclang.scale.injector.binary { pack_binary_bytes }
import from tests.scale.support { pod_binary, require_pod_binary }
import from jaclang.compiler.driver.jir {
    FLAG_PRECOMPILED,
    compute_module_key,
    compute_precompile_module_key,
    module_cache_key,
    precompiled_jir_matches_source,
    running_compiler_digest,
    write_precompiled_jir
}


glob _JAC_BIN: Path = pod_binary();


test "identical content packs to identical bytes (content-address stable)" {
    # Content-addressed seed-skip only works if the archives are deterministic:
    # zeroed gzip header time and normalized member mtimes/owners.
    assert pack_binary_bytes(b"ELF") == pack_binary_bytes(b"ELF");

    require_pod_binary();
    binary = _JAC_BIN.read_bytes();
    d = tempfile.mkdtemp();
    src = Path(d, "svc.jac");
    src.write_text("with entry { print(\"ok\"); }");
    first = pack_jab(d, binary);
    # A different mtime on the same content must not change the digest.
    os.utime(str(src), (0, 0));
    try {
        assert content_address(pack_jab(d, binary)) == content_address(first);
    } finally {
        import shutil;
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a different compiler image changes the payload precompile module key" {
    with tempfile.TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "probe.jac");
        Path(src).write_text("with entry { print(1); }\n");
        before = "image:before";
        after = "image:after";
        assert compute_precompile_module_key(src, before)
            != compute_precompile_module_key(src, after) , "the payload module key survived a codegen change at one version";
        assert compute_precompile_module_key(src, before)
            == compute_precompile_module_key(src, before);
        assert compute_precompile_module_key(src)
            == compute_precompile_module_key(src, running_compiler_digest());
    }
}


test "the payload seed is reusable only for the compiler that wrote it" {
    with tempfile.TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "probe.jac");
        Path(src).write_text("with entry { print(1); }\n");
        before = "image:before";
        after = "image:after";
        seed = write_precompiled_jir(
            b"marshalled", compute_precompile_module_key(src, before), FLAG_PRECOMPILED
        );
        assert precompiled_jir_matches_source(seed, src, before) , "an unchanged compiler must still reuse its own seed";
        assert not precompiled_jir_matches_source(seed, src, after) , "the seed served a jir compiled by a different compiler";
    }
}


test "the running compiler digest names its compiled image" {
    import jaclang;
    import from jaclang.image { load_image }
    image = load_image(Path(jaclang.__file__).parent / "_precompiled");
    assert image is not None;
    assert running_compiler_digest() == image.manifest["compiler_digest"];
    assert running_compiler_digest().startswith("image:");
}

test "the per-module JIR cache key stays compiler-agnostic" {
    import jaclang.compiler.driver.jir as jir;
    with tempfile.TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "probe.jac");
        Path(src).write_text("with entry { print(1); }\n");
        local = module_cache_key(src);
        payload = compute_precompile_module_key(src);
        assert compute_module_key(src) == local;
        assert payload != local;
        saved = list(jir._COMPILER_DIGEST_CACHE);
        try {
            jir._COMPILER_DIGEST_CACHE.clear();
            jir._COMPILER_DIGEST_CACHE.append("7:0123456789abcdef");
            assert compute_precompile_module_key(src) != payload , "the payload key ignored the compiler it was built by";
            assert module_cache_key(src) == local , "compiler identity leaked into the local per-module cache key";
        } finally {
            jir._COMPILER_DIGEST_CACHE.clear();
            jir._COMPILER_DIGEST_CACHE.extend(saved);
        }
    }
}
