import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.dist.payload.artifacts { ArtifactStore }

test "artifact expiry retains recently used and locked producers" {
    import os;
    import time;
    with TemporaryDirectory() as directory {
        base = Path(directory);
        store = ArtifactStore(base / "cache", ttl_days=1);
        source = base / "input";
        source.write_bytes(b"artifact");
        for key in ["a" * 64, "b" * 64, "c" * 64] {
            store.publish("test", key, {"result": source});
        }
        old = time.time() - 3 * 86400;
        for key in ["a" * 64, "b" * 64] {
            os.utime(store.location("test", key), (old, old));
        }
        store.swept.clear();
        with store.lock("test", "b" * 64) {
            store.prune("test", "d" * 64);
        }
        assert not store.location("test", "a" * 64).exists();
        assert store.location("test", "b" * 64).exists();
        assert store.location("test", "c" * 64).exists();
    }
}

import from jaclang.dist.payload.assemble { precompile_env }

test "completed artifacts require every member and reject corrupted data" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        store = ArtifactStore(base / "cache");
        library = base / "library.so";
        layout = base / "layout.json";
        library.write_bytes(b"library");
        layout.write_bytes(b"layout");
        outputs = {"library": library, "layout": layout};
        key = "a" * 64;
        with store.lock("kernel", key) {
            assert not store.restore("kernel", key, outputs);
            store.publish("kernel", key, outputs);
            library.unlink();
            layout.unlink();
            assert store.restore("kernel", key, outputs);
            assert library.read_bytes() == b"library";
            assert layout.read_bytes() == b"layout";
            (store.location("kernel", key) / "layout").write_bytes(b"corrupt");
            library.write_bytes(b"destination");
            assert not store.restore("kernel", key, outputs);
            assert library.read_bytes() == b"destination";
            store.publish("kernel", key, outputs);
            (store.location("kernel", key) / "manifest.json").unlink();
            assert not store.restore("kernel", key, outputs);
        }
    }
}

test "precompile explicitly selects the staged kernel or its bootstrap fallback" {
    import sys;
    with TemporaryDirectory() as directory {
        site = Path(directory) / "site";
        kernel = site
            / "jaclang/compiler"
            / (
                "libjac_compiler.dylib"
                    if sys.platform == "darwin"
                    else "libjac_compiler.so"
            );
        with patch.dict(os.environ, {"JAC_COMPILER_LIB": "/unrelated/kernel.so"}) {
            assert precompile_env(directory, str(site))["JAC_COMPILER_LIB"] == "off";
            kernel.parent.mkdir(parents=True);
            kernel.write_bytes(b"library");
            assert precompile_env(directory, str(site))["JAC_COMPILER_LIB"] == "off";
            Path(str(kernel) + ".layout.json").write_bytes(b"layout");
            assert precompile_env(directory, str(site))["JAC_COMPILER_LIB"]
                == str(kernel);
        }
    }
}

test "kernel packaging restores a complete pair across staging directories" {
    import sys;
    import jaclang.dist.payload.assemble as assembly;
    with TemporaryDirectory() as directory {
        base = Path(directory);
        repository = base / "source";
        source = repository / "jaclang/compiler/jc_unit.jac";
        source.parent.mkdir(parents=True);
        source.write_text("def probe() -> int { return 42; }\n");
        shim = base / "shim.so";
        shim.write_bytes(b"shim");
        opts = assembly.MkPayloadOpts(
            shim_so=str(shim), layer_cache=str(base / "cache")
        );
        name = "libjac_compiler.dylib"
            if sys.platform == "darwin"
            else "libjac_compiler.so";
        produced: list[str] = [];
        def child(
            argv: list[str], env: dict[str, str] | None, allow_fail: bool
        ) -> bool {
            output = Path(argv[-1]);
            output.parent.mkdir(parents=True, exist_ok=True);
            output.write_bytes(b"kernel");
            Path(str(output) + ".layout.json").write_bytes(b"layout");
            produced.append(str(output));
            return True;
        }
        with patch.object(assembly, "run_child", side_effect=child) {
            assembly.build_compiler_kernel(str(repository), str(base / "one"), opts);
            assembly.build_compiler_kernel(str(repository), str(base / "two"), opts);
            assert len(produced) == 1;
            assert (base / "two/jaclang/compiler" / name).read_bytes() == b"kernel";
            assert not (source.parent / name).exists();
            assert opts.measurements.cache_outcomes["compiler_kernel"]
                == {"miss": 1, "hit": 1};
            source.write_text("def probe() -> int { return 43; }\n");
            assembly.build_compiler_kernel(str(repository), str(base / "three"), opts);
            assert len(produced) == 2;
        }
    }
}

test "Python bytecode reuses unchanged files after relocation and compiles only edits" {
    import marshal;
    import py_compile;
    import shutil;
    import sys;
    import from jaclang.dist.payload.python_bytecode { precompile_tree }
    with TemporaryDirectory() as directory {
        base = Path(directory);
        first = base / "first/site";
        first.mkdir(parents=True);
        (first / "one.py").write_text("answer = 42\n");
        (first / "two.py").write_text("answer = 47\n");
        cache = str(base / "cache");
        assert precompile_tree(sys.executable, str(base / "first"), cache)
            == {"compiled": 2, "reused": 0};
        shutil.copytree(base / "first", base / "second");
        with patch.object(
            py_compile,
            "compile",
            side_effect=AssertionError("unchanged source compiled")
        ) {
            assert precompile_tree(sys.executable, str(base / "second"), cache)
                == {"compiled": 0, "reused": 2};
        }
        (base / "second/site/one.py").write_text("answer = 43\n");
        assert precompile_tree(sys.executable, str(base / "second"), cache)
            == {"compiled": 1, "reused": 1};
        generated = next((base / "second/site/__pycache__").glob("one.*.pyc"));
        code = marshal.loads(generated.read_bytes()[16:]);
        assert code.co_filename == "/jac-rt/site/one.py";
        namespace: dict[str, any] = {};
        exec(code, namespace);
        assert namespace["answer"] == 43;
    }
}

test "a distinct target interpreter batches only Python bytecode misses" {
    import marshal;
    import sys;
    import jaclang.dist.payload.python_bytecode as bytecode;
    with TemporaryDirectory() as directory {
        base = Path(directory);
        stage = base / "stage";
        stage.mkdir();
        (stage / "value.py").write_text("answer = 42\n");
        with patch.object(bytecode, "current_identity", return_value={}) {
            assert bytecode.precompile_tree(
                sys.executable, str(stage), str(base / "cache")
            )
                == {"compiled": 1, "reused": 0};
            generated = next((stage / "__pycache__").glob("value.*.pyc"));
            code = marshal.loads(generated.read_bytes()[16:]);
            assert code.co_filename == "/jac-rt/value.py";
            generated.unlink();
            assert bytecode.precompile_tree(
                sys.executable, str(stage), str(base / "cache")
            )
                == {"compiled": 0, "reused": 1};
            assert generated.is_file();
        }
    }
}
