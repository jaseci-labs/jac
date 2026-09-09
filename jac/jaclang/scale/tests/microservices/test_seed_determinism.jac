import os;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.bundle { pack_jab, content_address }
import from jaclang.scale.injector.binary { pack_binary_bytes }
import from jaclang.scale.tests.support { pod_binary, require_pod_binary }
import from jaclang.compiler.driver.jir {
    FLAG_PRECOMPILED,
    compiler_source_digest,
    compiler_source_files,
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


def _stage_compiler_tree(where: str, codegen_body: str) -> str {
    pkg = Path(where, "jaclang");
    for rel in [
        "jac0.py",
        "compiler/driver/jir.jac",
        "compiler/backends/py/jcir_gen_pass.jac",
        "compiler/backends/native/llvm/libjacllvm.so",
        "dist/precompile_bytecode.jac",
        "server/machine.jac",
        "compiler/__pycache__/stale.py",
        "compiler/.jac/cache/hidden.jac",
        "compiler/tests/test_lowering.jac",
        "compiler/tests/fixtures/corpus.jac",
        "compiler/backends/py/jcir_gen_pass.test.jac"
    ] {
        f = pkg / rel;
        f.parent.mkdir(parents=True, exist_ok=True);
        f.write_text(f"stub for {rel}\n");
    }
    (pkg / "compiler/backends/py/jcir_gen_pass.jac").write_text(codegen_body);
    return str(pkg);
}


test "the compiler digest is content-addressed, not path- or mtime-addressed" {
    with tempfile.TemporaryDirectory() as tmp {
        a = _stage_compiler_tree(os.path.join(tmp, "one"), "emit(1);\n");
        b = _stage_compiler_tree(os.path.join(tmp, "two-longer-path"), "emit(1);\n");
        for (walk_dir, _dirs, files) in os.walk(b) {
            for name in files {
                os.utime(os.path.join(walk_dir, name), (0, 0));
            }
        }
        assert compiler_source_digest(a) == compiler_source_digest(b) , "absolute path or mtime leaked into the compiler digest";
        assert compiler_source_digest(a) == compiler_source_digest(a);
    }
}


test "a compiler source edit changes the compiler digest" {
    with tempfile.TemporaryDirectory() as tmp {
        a = _stage_compiler_tree(os.path.join(tmp, "before"), "emit(1);\n");
        b = _stage_compiler_tree(os.path.join(tmp, "after"), "emit(2);\n");
        assert compiler_source_digest(a) != compiler_source_digest(b) , "a codegen pass edit left the compiler digest unchanged";
    }
}


test "the compiler digest ignores build artifacts and non-compiler modules" {
    with tempfile.TemporaryDirectory() as tmp {
        a = _stage_compiler_tree(os.path.join(tmp, "base"), "emit(1);\n");
        base = compiler_source_digest(a);
        for (rel, text) in [
            ("compiler/backends/native/llvm/libjacllvm.so", "relinked shim\n"),
            ("server/machine.jac", "runtime edit\n"),
            ("compiler/__pycache__/stale.py", "byte cache\n"),
            ("compiler/.jac/cache/hidden.jac", "cache droppings\n"),
            ("compiler/tests/test_lowering.jac", "new compiler test\n"),
            ("compiler/tests/fixtures/corpus.jac", "new fixture\n"),
            ("compiler/backends/py/jcir_gen_pass.test.jac", "new annex test\n")
        ] {
            Path(a, rel).write_text(text);
            assert compiler_source_digest(a) == base , f"{rel} must not participate in the compiler digest";
        }
    }
}


test "a compiler source edit changes the payload precompile module key" {
    with tempfile.TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "probe.jac");
        Path(src).write_text("with entry { print(1); }\n");
        before = compiler_source_digest(
            _stage_compiler_tree(os.path.join(tmp, "before"), "emit(1);\n")
        );
        after = compiler_source_digest(
            _stage_compiler_tree(os.path.join(tmp, "after"), "emit(2);\n")
        );
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
        before = compiler_source_digest(
            _stage_compiler_tree(os.path.join(tmp, "before"), "emit(1);\n")
        );
        after = compiler_source_digest(
            _stage_compiler_tree(os.path.join(tmp, "after"), "emit(2);\n")
        );
        seed = write_precompiled_jir(
            b"marshalled", compute_precompile_module_key(src, before), FLAG_PRECOMPILED
        );
        assert precompiled_jir_matches_source(seed, src, before) , "an unchanged compiler must still reuse its own seed";
        assert not precompiled_jir_matches_source(seed, src, after) , "the seed served a jir compiled by a different compiler";
    }
}


test "the running compiler digest covers the real compiler tree" {
    import jaclang;
    pkg = os.path.dirname(os.path.abspath(jaclang.__file__));
    rels = compiler_source_files(pkg);
    for expected in [
        "jac0.py",
        "compiler/driver/jir.jac",
        "compiler/frontend/unitree.jac",
        "compiler/backends/py/jcir_gen_pass.jac",
        "compiler/backends/py/jcir_gen_pass.impl/expr.impl.jac",
        "compiler/backends/native/na_ir_gen_pass.impl/core.impl.jac",
        "compiler/passes/type_checker_pass.jac",
        "dist/precompile_bytecode.jac"
    ] {
        assert expected in rels , f"{expected} is outside the compiler digest";
    }
    assert len(rels) > 250;
    assert len(rels) == len(set(rels));
    assert rels == sorted(rels);
    for rel in rels {
        assert "/tests/" not in rel and not rel.startswith("tests/") , f"{rel} is test material and must not gate the seed";
        assert rel.endswith(".jac") or rel.endswith(".py");
    }
    assert running_compiler_digest() == compiler_source_digest(pkg);
    assert running_compiler_digest() == running_compiler_digest();
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
