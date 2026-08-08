"""Tests for Jac Loader."""

import io;
import os;
import sys;
import gc;
import weakref;
import subprocess;
import marshal;
import shutil;
import tempfile;
import time;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang { JacRuntime as Jac }
import from jaclang { JacRuntimeInterface }
import from jaclang.cli.commands { execution }
import from jaclang.cli.commands { analysis }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compiler { JacCompiler }
import from jaclang.jac0core.jir {
    get_module_cache_path,
    read_bytecode_only,
    SEC_LLVM_IR,
    SECTIONS_MAGIC,
    HEADER_SIZE,
    read_sections
}

glob TEST_DIR = os.path.join(JAC_ROOT, "tests", "compiler"),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "fixtures"),
     LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures"),
     _test_tmp_dir: str = tempfile.mkdtemp(prefix="jac_test_importer_");

test "import basic python" {
    sys.modules.pop("fixtures", None);
    sys.modules.pop("fixtures.hello_world", None);
    Jac.set_base_path(TEST_DIR);
    JacRuntimeInterface.attach_program(JacProgram());
    (h, ) = Jac.jac_import("fixtures.hello_world", base_path=TEST_DIR);
    assert h.hello() == "Hello World!";
}

test "modules correct" {
    sys.modules.pop("fixtures", None);
    sys.modules.pop("fixtures.hello_world", None);
    Jac.set_base_path(TEST_DIR);
    JacRuntimeInterface.attach_program(JacProgram());
    Jac.jac_import("fixtures.hello_world", base_path=TEST_DIR);
    assert "module 'fixtures.hello_world'" in str(Jac.loaded_modules);
    assert "/tests/compiler/fixtures/hello_world.jac"
        in str(Jac.loaded_modules).replace("\\\\", "/");
}

test "jac py import" {
    fixture_file = os.path.join(LANG_FIXTURES, "jp_importer.jac");
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    execution.run(fixture_file);
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "Hello World!" in stdout_value;
    assert (
        "{SomeObj(a=10): 'check'} [MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]"
        in stdout_value
    );
}

test "jac py import auto" {
    fixture_file = os.path.join(LANG_FIXTURES, "jp_importer_auto.jac");
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    execution.run(fixture_file);
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "Hello World!" in stdout_value;
    assert (
        "{SomeObj(a=10): 'check'} [MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]"
        in stdout_value
    );
}

test "import with jacpath" {
    jacpath_dir = tempfile.TemporaryDirectory();
    os.environ["JACPATH"] = jacpath_dir.name;

    module_name = "test_module";
    jac_file_path = os.path.join(jacpath_dir.name, f"{module_name}.jac");
    with open(jac_file_path, "w") as f {
        f.write(
            '\n            with entry {\n                "Hello from JACPATH!" :> print;\n            }\n            '
        );
    }

    captured_output = io.StringIO();
    sys.stdout = captured_output;

    try {
        Jac.set_base_path(TEST_DIR);
        JacRuntimeInterface.attach_program(JacProgram());
        Jac.jac_import(module_name, base_path=TEST_DIR);
        execution.run(jac_file_path);

        sys.stdout = sys.__stdout__;
        stdout_value = captured_output.getvalue();

        assert "Hello from JACPATH!" in stdout_value;
    } finally {
        captured_output.close();
        os.environ.pop("JACPATH", None);
        jacpath_dir.cleanup();
    }
}

test "importer with submodule jac" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    execution.run(os.path.join(FIXTURES, "pkg_import_main.jac"));
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "Helper function called" in stdout_value;
    assert "Tool function executed" in stdout_value;
}

test "importer with submodule py" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    execution.run(os.path.join(FIXTURES, "pkg_import_main_py.jac"));
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "Helper function called" in stdout_value;
    assert "Tool function executed" in stdout_value;
    assert "pkg_import_lib_py.glob_var_lib" in stdout_value;
}

test "python dash m jac module" {
    with tempfile.TemporaryDirectory() as tmpdir {
        sitecustomize_file = os.path.join(tmpdir, "sitecustomize.py");
        with open(sitecustomize_file, "w") as f {
            f.write("import jaclang\n");
        }
        module_name = "test_dash_m_module";
        jac_file = os.path.join(tmpdir, f"{module_name}.jac");
        with open(jac_file, "w") as f {
            f.write('with entry { "python -m works" :> print; }\n');
        }
        env = os.environ.copy();
        env["PYTHONPATH"] = os.pathsep.join(
            p
            for p in [tmpdir, env.get("PYTHONPATH")]
            if p
        );
        result = subprocess.run(
            [sys.executable, "-m", module_name],
            capture_output=True,
            text=True,
            cwd=tmpdir,
            env=env
        );
        assert result.returncode == 0 , f"Failed with stderr: {result.stderr}";
        assert "python -m works" in result.stdout;
    }
}

test "python dash m jac package" {
    with tempfile.TemporaryDirectory() as tmpdir {
        sitecustomize_file = os.path.join(tmpdir, "sitecustomize.py");
        with open(sitecustomize_file, "w") as f {
            f.write("import jaclang\n");
        }
        pkg_name = "test_pkg";
        pkg_dir = os.path.join(tmpdir, pkg_name);
        os.makedirs(pkg_dir);
        init_file = os.path.join(pkg_dir, "__init__.jac");
        with open(init_file, "w") as f {
            f.write("# Package init\n");
        }
        main_file = os.path.join(pkg_dir, "__main__.jac");
        with open(main_file, "w") as f {
            f.write('with entry { "package main works" :> print; }\n');
        }
        env = os.environ.copy();
        env["PYTHONPATH"] = os.pathsep.join(
            p
            for p in [tmpdir, env.get("PYTHONPATH")]
            if p
        );
        result = subprocess.run(
            [sys.executable, "-m", pkg_name],
            capture_output=True,
            text=True,
            cwd=tmpdir,
            env=env
        );
        assert result.returncode == 0 , f"Failed with stderr: {result.stderr}";
        assert "package main works" in result.stdout;
    }
}

test "compiler separates internal from user modules" {
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as tmp_file {
        tmp_file.write('with entry { "hello" :> print; }\n');
        user_file = tmp_file.name;
    }

    old_compiler = Jac.compiler;
    old_program = Jac.program;
    Jac.compiler = None;
    Jac.program = None;

    try {
        captured_output = io.StringIO();
        sys.stdout = captured_output;
        execution.run(user_file);
        sys.stdout = sys.__stdout__;

        assert "hello" in captured_output.getvalue();

        compiler = Jac.get_compiler();
        user_program = Jac.get_program();
        jaclang_root = compiler._get_jaclang_root();

        internal_hub_paths = list(compiler.internal_program.mod.hub.keys());
        user_hub_paths = list(user_program.mod.hub.keys());

        assert len(user_hub_paths) > 0 , "User program hub should not be empty";

        for path in internal_hub_paths {
            assert path.startswith(jaclang_root) , (
                f"Non-jaclang path {path} found in compiler's internal hub"
            );
        }

        for path in user_hub_paths {
            assert not path.startswith(jaclang_root) , (
                f"Jaclang internal path {path} found in user's program hub"
            );
        }
    } finally {
        os.unlink(user_file);
        Jac.compiler = old_compiler;
        Jac.program = old_program;
    }
}

test "get bytecode uses JIR cache on second call" {
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as tmp {
        tmp.write("glob x = 1;\n");
        tmp.flush();
        jac_file = tmp.name;
    }

    past = time.time() - 2;
    os.utime(jac_file, (past, past));

    try {
        compiler = JacCompiler();
        prog1 = JacProgram();
        code1 = compiler.get_bytecode(jac_file, prog1);
        assert code1 is not None , "First compilation should succeed";

        # JIR cache should exist and contain bytecode section
        cache_path = get_module_cache_path(jac_file);
        assert cache_path.exists() , "JIR cache file should exist after first compile";
        jir_data = cache_path.read_bytes();
        bc = read_bytecode_only(jir_data);
        assert bc is not None , "JIR cache should contain bytecode section";

        # Second call should return identical bytecode from cache
        prog2 = JacProgram();
        code2 = compiler.get_bytecode(jac_file, prog2);
        assert code2 is not None , "Second call should return cached bytecode";
        assert marshal.dumps(code1) == marshal.dumps(code2);
    } finally {
        os.unlink(jac_file);
        cache_path2 = get_module_cache_path(jac_file);
        if cache_path2.exists() {
            cache_path2.unlink();
        }
    }
}

test "type evaluator uses JIR cache for pyi stubs" {
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".pyi", delete=False, dir=_test_tmp_dir
    ) as tmp {
        tmp.write("class Foo:\n    x: int\n");
        tmp.flush();
        stub_file = tmp.name;
    }

    past = time.time() - 2;
    os.utime(stub_file, (past, past));

    try {
        prog1 = JacProgram();
        mod1 = prog1.load_dependency_module(stub_file);
        sym1 = mod1.sym_tab.lookup("Foo");
        assert sym1 is not None , "Foo symbol missing after first pyi import";

        cache_path = get_module_cache_path(stub_file);
        assert cache_path.exists() , "JIR cache file should exist after first pyi import";

        prog2 = JacProgram();
        mod2 = prog2.load_dependency_module(stub_file);
        sym2 = mod2.sym_tab.lookup("Foo");
        assert sym2 is not None , "Foo symbol missing after JIR cache read";

        import from jaclang.jac0core.unitree { Archetype }
        import from jaclang.jac0core.constant { Tokens as Tok }
        foo2: list = [];
        for a in mod2.get_all_sub_nodes(Archetype) {
            if a.name is not None and a.name.value == "Foo" {
                foo2.append(a);
            }
        }
        assert len(foo2) == 1 , "Foo archetype missing after JIR cache read";
        assert foo2[0].arch_type is not None , "arch_type lost in JIR round-trip";
        assert foo2[0].arch_type.name == Tok.KW_CLASS , (
            "arch_type wrong after JIR round-trip"
        );
        assert mod2.source is not None , "cached stub should retain source";
        assert stub_file in mod2.source.file_path
            or os.path.basename(stub_file) in mod2.source.file_path , (
            "module.source must reference original .pyi path"
        );

        future = time.time() + 5;
        os.utime(stub_file, (future, future));
        prog3 = JacProgram();
        mod3 = prog3.load_dependency_module(stub_file);
        assert mod3.sym_tab.lookup("Foo") is not None , (
            "stale JIR cache reused after pyi edit"
        );
    } finally {
        os.unlink(stub_file);
        cache_path2 = get_module_cache_path(stub_file);
        if cache_path2.exists() {
            cache_path2.unlink();
        }
    }
}

test "load_dependency_module uses JIR cache without recompiling" {
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".pyi", delete=False, dir=_test_tmp_dir
    ) as tmp {
        tmp.write("class Bar:\n    y: str\n");
        tmp.flush();
        stub_file = tmp.name;
    }
    past = time.time() - 2;
    os.utime(stub_file, (past, past));
    compile_calls = 0;
    orig_compile = JacProgram.compile;
    def counting_compile(
        self: JacProgram,
        file_path: str,
        use_str: (str | None) = None,
        no_cgen: bool = False,
        type_check: bool = False,
        symtab_ir_only: bool = False,
        cancel_token = None,
        options = None
    ) -> object {
        compile_calls += 1;
        return orig_compile(
            self,
            file_path,
            use_str=use_str,
            no_cgen=no_cgen,
            type_check=type_check,
            symtab_ir_only=symtab_ir_only,
            cancel_token=cancel_token,
            options=options
        );
    }
    JacProgram.compile = counting_compile;
    try {
        prog1 = JacProgram();
        prog1.load_dependency_module(stub_file);
        assert compile_calls == 0 , (
            "first .pyi load should use PyastBuildPass, not compile"
        );
        cache_path = get_module_cache_path(stub_file);
        assert cache_path.exists() , "first .pyi load should write JIR cache";

        prog2 = JacProgram();
        prog2.load_dependency_module(stub_file);
        assert compile_calls == 0 , "warm cache should skip compile";
    } finally {
        JacProgram.compile = orig_compile;
        os.unlink(stub_file);
        cache_path = get_module_cache_path(stub_file);
        if cache_path.exists() {
            cache_path.unlink();
        }
    }
}

test "resolve_import_source_module uses JIR cache without recompiling" {
    import jaclang.jac0core.unitree as uni;
    import from jaclang.compiler.symbol_utils { resolve_import_source_module }

    with tempfile.TemporaryDirectory(dir=_test_tmp_dir) as d {
        stub_name = "cache_probe.pyi";
        stub_file = os.path.join(d, stub_name);
        with open(stub_file, "w") as f {
            f.write("class CacheProbe:\n    v: int\n");
        }
        past = time.time() - 2;
        os.utime(stub_file, (past, past));
        importer_file = os.path.join(d, "importer.jac");
        with open(importer_file, "w") as f {
            f.write('import from "' + stub_name + '" { CacheProbe }\n');
        }
        compile_calls = 0;
        orig_compile = JacProgram.compile;
        def counting_compile(
            self: JacProgram,
            file_path: str,
            use_str: (str | None) = None,
            no_cgen: bool = False,
            type_check: bool = False,
            symtab_ir_only: bool = False,
            cancel_token = None,
            options = None
        ) -> object {
            compile_calls += 1;
            return orig_compile(
                self,
                file_path,
                use_str=use_str,
                no_cgen=no_cgen,
                type_check=type_check,
                symtab_ir_only=symtab_ir_only,
                cancel_token=cancel_token,
                options=options
            );
        }
        JacProgram.compile = counting_compile;
        try {
            prog1 = JacProgram();
            mod1 = prog1.parse_str(
                'import from "' + stub_name + '" { CacheProbe }\n', importer_file
            );
            imports1 = [
                stmt
                for stmt in mod1.body
                if isinstance(stmt, uni.Import)
            ];
            assert len(imports1) == 1 , "expected one import statement";
            resolve_import_source_module(prog1, imports1[0]);
            assert compile_calls == 0 , (
                "first .pyi resolve should use PyastBuildPass, not compile"
            );
            cache_path = get_module_cache_path(stub_file);
            assert cache_path.exists() , "first .pyi resolve should write JIR cache";

            prog2 = JacProgram();
            mod2 = prog2.parse_str(
                'import from "' + stub_name + '" { CacheProbe }\n', importer_file
            );
            imports2 = [
                stmt
                for stmt in mod2.body
                if isinstance(stmt, uni.Import)
            ];
            resolve_import_source_module(prog2, imports2[0]);
            assert compile_calls == 0 , "warm cache should skip compile";
        } finally {
            JacProgram.compile = orig_compile;
            cache_path = get_module_cache_path(stub_file);
            if cache_path.exists() {
                cache_path.unlink();
            }
        }
    }
}

test "corrupt pyi JIR cache falls back to source compile" {
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".pyi", delete=False, dir=_test_tmp_dir
    ) as tmp {
        tmp.write("class Baz:\n    z: int\n");
        tmp.flush();
        stub_file = tmp.name;
    }
    past = time.time() - 2;
    os.utime(stub_file, (past, past));
    try {
        prog1 = JacProgram();
        prog1.load_dependency_module(stub_file);
        cache_path = get_module_cache_path(stub_file);
        assert cache_path.exists() , "cache should exist";
        cache_path.write_bytes(b"corrupt-jir-data");

        prog2 = JacProgram();
        mod = prog2.load_dependency_module(stub_file);
        assert mod.sym_tab.lookup("Baz") is not None , (
            "corrupt cache should fall back to source compile"
        );
    } finally {
        os.unlink(stub_file);
        cache_path2 = get_module_cache_path(stub_file);
        if cache_path2.exists() {
            cache_path2.unlink();
        }
    }
}

test "stub module cache key is source focused" {
    import from jaclang.jac0core.jir {
        compute_module_key,
        compute_stub_module_key,
        module_cache_key,
    }
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".pyi", delete=False, dir=_test_tmp_dir
    ) as tmp {
        tmp.write("class KeyProbe:\n    k: int\n");
        tmp.flush();
        stub_file = tmp.name;
    }
    try {
        stub_key = compute_stub_module_key(stub_file);
        assert stub_key == module_cache_key(stub_file) , (
            "module_cache_key should use stub key for .pyi"
        );
        jac_key = compute_module_key(stub_file);
        assert stub_key != jac_key , (
            "stub cache key should not include placement/client config"
        );
    } finally {
        os.unlink(stub_file);
    }
}

test "get_bytecode busts in-memory hub when .impl.jac changes" {
    # Regression: in a persistent process, editing a .impl.jac annex left a
    # stale in-memory module in mod.hub; get_bytecode returned it with no
    # freshness check. Cold runs were fine (disk cache busts via modkey).
    with tempfile.TemporaryDirectory(dir=_test_tmp_dir) as d {
        mod = os.path.join(d, "mod.jac");
        impl_file = os.path.join(d, "mod.impl.jac");
        with open(mod, "w") as f {
            f.write(
                "obj Thing {\n    has tag: int = 0;\n    def get_tag() -> int;\n}\n"
            );
        }
        def write_body(v: int) {
            with open(impl_file, "w") as f {
                f.write(
                    "impl Thing.get_tag() -> int {\n    return " + str(v) + ";\n}\n"
                );
            }
        }
        write_body(10);
        past = time.time() - 5;
        os.utime(mod, (past, past));
        os.utime(impl_file, (past, past));
        compiler = JacCompiler();
        prog = JacProgram();
        def tag_of -> int {
            code = compiler.get_bytecode(mod, prog);
            ns: dict = {};
            exec(code, ns);
            return ns["Thing"]().get_tag();
        }
        assert tag_of() == 10 , "first compile should use the annex body";
        # edit the annex in the SAME persistent process
        write_body(20);
        future = time.time() + 5;
        os.utime(impl_file, (future, future));
        got = tag_of();
        assert got == 20 , (
            "stale in-memory hub bytecode reused; expected 20 after "
            + "annex edit, got "
            + str(got)
        );
    }
}

test "check preserves caller GC state" {
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as tmp {
        tmp.write("glob check_value = 1;\n");
        check_file = tmp.name;
    }
    was_enabled = gc.isenabled();
    gc.disable();
    try {
        assert analysis.check([check_file], print_errs=False) == 0;
        assert not gc.isenabled();
    } finally {
        if was_enabled {
            gc.enable();
        } else {
            gc.disable();
        }
        os.unlink(check_file);
    }
}

test "release compile closure clears ASTs and evaluator but keeps stubs" {
    with tempfile.TemporaryDirectory(dir=_test_tmp_dir) as d {
        source_path = os.path.join(d, "source.jac");
        stub_path = os.path.join(d, "types.pyi");
        prog = JacProgram();
        def source_ref -> object {
            source_mod = prog.parse_str("glob value = 1;\n", source_path);
            return weakref.ref(source_mod);
        }
        ast_ref = source_ref();
        prog.parse_str("value: int\n", stub_path);
        prog.get_type_evaluator();
        prog.release_compile_closure(keep_stubs=True);
        gc.collect();
        assert ast_ref() is None , "released AST is still strongly referenced";
        assert source_path not in prog.mod.hub;
        assert stub_path in prog.mod.hub;
        assert prog.type_evaluator is None;
    }
}

test "release compile closure honors no unit eviction" {
    with tempfile.TemporaryDirectory(dir=_test_tmp_dir) as d {
        source_path = os.path.join(d, "source.jac");
        prog = JacProgram();
        prog.parse_str("glob value = 1;\n", source_path);
        old_no_evict = os.environ.get("JAC_NO_UNIT_EVICT");
        os.environ["JAC_NO_UNIT_EVICT"] = "1";
        try {
            prog.release_compile_closure();
            assert source_path in prog.mod.hub;
        } finally {
            if old_no_evict is None {
                os.environ.pop("JAC_NO_UNIT_EVICT", None);
            } else {
                os.environ["JAC_NO_UNIT_EVICT"] = old_no_evict;
            }
        }
    }
}

test "release compile closure keeps synthesized type identity stable" {
    # `jac check`/`jac lint` release each file's compile closure between files,
    # which drops and recreates the type evaluator. LiteralString is synthesized
    # (not a real stub class), so re-minting it per evaluator gave it a fresh
    # identity every file while the stub AST it derives from (str) survives with
    # the prior instance cached on it -- breaking `Literal[...] <: LiteralString`
    # and surfacing spurious E1001s on every checked file after the first. The
    # synthesized type must be memoized on the (stable) str class so it survives
    # evaluator churn.
    prog = JacProgram();
    ev1 = prog.get_type_evaluator();
    ls1 = ev1.prefetch.literal_string_class;
    assert ls1 is not None , "LiteralString was not prefetched";
    prog.release_compile_closure();
    assert prog.type_evaluator is None;
    ev2 = prog.get_type_evaluator();
    ls2 = ev2.prefetch.literal_string_class;
    assert ls2 is not None;
    assert ev1 is not ev2 , "evaluator was not recreated";
    assert ls1.shared is ls2.shared , "LiteralString identity changed across evaluator recreation";
}

test "internal get_bytecode evicts unit AST after compile" {
    # Cold bootstrap used to retain every jaclang module AST in
    # internal_program.mod.hub. After the outermost successful compile+cache
    # write, non-stub ASTs must leave the hub so peak RSS stays near one import
    # closure (+ warm typeshed), not the union of every module ever compiled.
    compiler = JacCompiler();
    prog = JacProgram();
    # Two small, already-shipped jaclang modules (always under jaclang_root →
    # resolve to internal_program). Force a fresh compile so we exercise the
    # post-compile eviction path rather than a disk-cache hit.
    samples = [
        os.path.join(compiler._get_jaclang_root(), "jac0core", "log.jac"),
        os.path.join(compiler._get_jaclang_root(), "jac0core", "constant.jac")
    ];
    for p in samples {
        assert os.path.isfile(p) , f"missing fixture {p}";
    }
    old_rebuild = os.environ.get("JAC_REBUILD");
    os.environ["JAC_REBUILD"] = "1";
    try {
        for p in samples {
            code = compiler.get_bytecode(p, prog);
            assert code is not None , f"compile failed for {p}";
            hub = compiler.internal_program.mod.hub;
            leftover_jac = [
                k
                for k in hub.keys()
                if not k.endswith(".pyi")
            ];
            assert len(leftover_jac) == 0 , (
                f"expected non-stub ASTs cleared after outermost get_bytecode of {p}; "
                f"hub still has {leftover_jac[:8]}"
            );
        }
    } finally {
        if old_rebuild is None {
            os.environ.pop("JAC_REBUILD", None);
        } else {
            os.environ["JAC_REBUILD"] = old_rebuild;
        }
    }
}
