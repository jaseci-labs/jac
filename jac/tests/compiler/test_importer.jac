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
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compiler { JacCompiler }
import from jaclang.compiler.driver.jir {
    get_module_cache_path,
    read_bytecode_only,
    SEC_PLACEMENT,
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
    old_selfhost = Jac.selfhost;
    Jac.compiler = None;
    Jac.program = None;
    # The self-host cache is process-wide; the separation assertions below
    # inspect its hub, so this test scopes a fresh one and restores the
    # shared cache afterward.
    Jac.selfhost = None;

    try {
        captured_output = io.StringIO();
        sys.stdout = captured_output;
        execution.run(user_file);
        sys.stdout = sys.__stdout__;

        assert "hello" in captured_output.getvalue();

        compiler = Jac.get_compiler();
        user_program = Jac.get_program();
        jaclang_root = compiler.selfhost.jaclang_root();

        internal_hub_paths = list(compiler.selfhost.program.mod.hub.keys());
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
        Jac.selfhost = old_selfhost;
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

test "pyi stubs derive identically in every process" {
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

        prog2 = JacProgram();
        mod2 = prog2.load_dependency_module(stub_file);
        sym2 = mod2.sym_tab.lookup("Foo");
        assert sym2 is not None , "Foo symbol missing on second derivation";

        import from jaclang.compiler.frontend.unitree { Archetype }
        import from jaclang.compiler.frontend.constant { Tokens as Tok }
        foo2: list = [];
        for a in mod2.get_all_sub_nodes(Archetype) {
            if a.name is not None and a.name.value == "Foo" {
                foo2.append(a);
            }
        }
        assert len(foo2) == 1 , "Foo archetype missing on second derivation";
        assert foo2[0].arch_type is not None , "arch_type missing on second derivation";
        assert foo2[0].arch_type.name == Tok.KW_CLASS , (
            "arch_type wrong on second derivation"
        );
        assert mod2.source is not None , "derived stub should retain source";
        assert stub_file in mod2.source.file_path
            or os.path.basename(stub_file) in mod2.source.file_path , (
            "module.source must reference original .pyi path"
        );

        future = time.time() + 5;
        os.utime(stub_file, (future, future));
        prog3 = JacProgram();
        mod3 = prog3.load_dependency_module(stub_file);
        assert mod3.sym_tab.lookup("Foo") is not None , (
            "edited pyi must derive fresh"
        );
    } finally {
        os.unlink(stub_file);
    }
}

test "pyi loads build via PyastBuildPass and never compile" {
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
    orig_compile: any = JacProgram.compile;
    def counting_compile(
        self: JacProgram,
        file_path: str,
        use_str: (str | None) = None,
        no_cgen: bool = False,
        symtab_ir_only: bool = False,
        cancel_token: any = None,
        options: any = None
    ) -> any {
        compile_calls += 1;
        return orig_compile(
            self,
            file_path,
            use_str=use_str,
            no_cgen=no_cgen,
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

        prog2 = JacProgram();
        prog2.load_dependency_module(stub_file);
        assert compile_calls == 0 , "second process's .pyi load must not compile either";
    } finally {
        JacProgram.compile = orig_compile;
        os.unlink(stub_file);
    }
}

test "Python star imports load dependency scopes once without checking implementation bodies" {
    import from unittest.mock { patch }
    with tempfile.TemporaryDirectory(dir=_test_tmp_dir) as tmpdir {
        first = os.path.join(tmpdir, "star_first.py");
        second = os.path.join(tmpdir, "star_second.py");
        with open(first, "w") as f {
            f.write("from star_second import *\nclass First: pass\n");
        }
        with open(second, "w") as f {
            f.write("from star_first import *\nclass Second: pass\n");
        }
        calls: list[tuple[str, bool]] = [];
        original: any = JacProgram.compile;
        def observe(
            self: JacProgram,
            file_path: str,
            use_str: (str | None) = None,
            no_cgen: bool = False,
            symtab_ir_only: bool = False,
            cancel_token: any = None,
            options: any = None
        ) -> any {
            if file_path.startswith(tmpdir) {
                calls.append((file_path, bool(options and options.symtab_ir_only)));
            }
            return original(
                self,
                file_path,
                use_str=use_str,
                no_cgen=no_cgen,
                symtab_ir_only=symtab_ir_only,
                cancel_token=cancel_token,
                options=options
            );
        }
        prog = JacProgram();
        with patch.object(JacProgram, "compile", observe) {
            module = prog.load_dependency_module(first);
        }
        assert module.sym_tab.lookup("First") is not None;
        assert module.sym_tab.lookup("Second") is not None;
        assert sorted(calls) == sorted([(first, True), (second, True)]) , (
            len(calls),
            calls[:6]
        );
        assert first in prog.deps.dependents[os.path.realpath(second)];
    }
}

test "resolve_import_source_module never compiles pyi stubs" {
    import jaclang.compiler.frontend.unitree as uni;
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
        orig_compile: any = JacProgram.compile;
        def counting_compile(
            self: JacProgram,
            file_path: str,
            use_str: (str | None) = None,
            no_cgen: bool = False,
            symtab_ir_only: bool = False,
            cancel_token: any = None,
            options: any = None
        ) -> any {
            compile_calls += 1;
            return orig_compile(
                self,
                file_path,
                use_str=use_str,
                no_cgen=no_cgen,
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
            assert compile_calls == 0 , "second resolve must not compile either";
        } finally {
            JacProgram.compile = orig_compile;
        }
    }
}

"""A cache newer than its source is not thereby valid: the mtime covers the
source bytes only, so every environment input the module key folds in (the node
schema, the analysis fingerprint, the placement/cut/codespace facts) must be
compared before the mtime fast path can accept the file.  #8181 shortened a
NODE_SPECS entry by one field, which a fresh-mtime cache written under the old
schema would then be decoded against, position by position."""
test "fresh mtime does not admit a cache written under a different environment" {
    import jaclang.compiler.driver.jir as jir;
    import from jaclang.compiler.driver.jir { is_module_cache_valid }
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as tmp {
        tmp.write("glob env_probe = 1;\n");
        tmp.flush();
        jac_file = tmp.name;
    }
    past = time.time() - 2;
    os.utime(jac_file, (past, past));
    try {
        compiler = JacCompiler();
        assert compiler.get_bytecode(jac_file, JacProgram()) is not None;
        cache_path = get_module_cache_path(jac_file);
        assert cache_path.exists() , "JIR cache was not written";
        assert os.path.getmtime(cache_path) > os.path.getmtime(jac_file) , (
            "cache must be newer than source for the mtime fast path to apply"
        );
        assert is_module_cache_valid(jac_file, cache_path) , "fresh cache should be valid";

        saved = list(jir._COMPILER_DIGEST_CACHE);
        try {
            jir._COMPILER_DIGEST_CACHE.clear();
            jir._COMPILER_DIGEST_CACHE.append("289:" + "0" * 64);
            assert not is_module_cache_valid(jac_file, cache_path) , (
                "a fresh mtime served a cache written under a different compiler"
            );
        } finally {
            jir._COMPILER_DIGEST_CACHE.clear();
            jir._COMPILER_DIGEST_CACHE.extend(saved);
        }
        assert is_module_cache_valid(jac_file, cache_path) , (
            "restoring the compiler digest should restore validity"
        );

        import from jaclang.compiler.driver.compile_options {
            push_native_target,
            pop_native_target
        }
        prev_tgt = push_native_target("wasm32-unknown-unknown");
        try {
            assert not is_module_cache_valid(jac_file, cache_path) , (
                "a fresh mtime served a cache written under a different "
                "analysis fingerprint"
            );
        } finally {
            pop_native_target(prev_tgt);
        }
        assert is_module_cache_valid(jac_file, cache_path) , (
            "restoring the analysis fingerprint should restore validity"
        );

        prev_opt = os.environ.get("JAC_OPT_LEVEL");
        try {
            os.environ["JAC_OPT_LEVEL"] = "0" if prev_opt != "0" else "1";
            assert is_module_cache_valid(jac_file, cache_path) , (
                "a native-only codegen knob (opt level) must not invalidate "
                "a bytecode cache"
            );
        } finally {
            if prev_opt is None {
                os.environ.pop("JAC_OPT_LEVEL", None);
            } else {
                os.environ["JAC_OPT_LEVEL"] = prev_opt;
            }
        }
    } finally {
        os.unlink(jac_file);
        cache_path2 = get_module_cache_path(jac_file);
        if cache_path2.exists() {
            cache_path2.unlink();
        }
    }
}

def _cached_pins(jir_bytes: bytes) -> dict[str, str] {
    import from jaclang.compiler.placement.placement { summary_from_bytes }
    pos = jir_bytes.find(SECTIONS_MAGIC, HEADER_SIZE);
    if pos < 0 {
        return {};
    }
    secs = read_sections(jir_bytes, pos + len(SECTIONS_MAGIC));
    placement = secs.get(SEC_PLACEMENT);
    if placement is None {
        return {};
    }
    summary = summary_from_bytes(placement);
    if summary is None {
        return {};
    }
    return {e.name: e.pinned for e in summary.elements};
}

test "editing placement pins in jac.toml invalidates the module cache" {
    import from jaclang.compiler.driver.jir { is_module_cache_valid }
    with tempfile.TemporaryDirectory(dir=_test_tmp_dir) as proj {
        toml_path = os.path.join(proj, "jac.toml");
        jac_file = os.path.join(proj, "m.jac");
        with open(toml_path, "w") as f {
            f.write('[project]\nname = "pins_cache_probe"\n');
        }
        with open(jac_file, "w") as f {
            f.write("def helper_fn() -> int { return 42; }\n");
        }
        past = time.time() - 2;
        os.utime(jac_file, (past, past));
        os.utime(toml_path, (past, past));
        compiler = JacCompiler();
        assert compiler.get_bytecode(jac_file, JacProgram()) is not None;
        cache_path = get_module_cache_path(jac_file);
        try {
            assert cache_path.exists() , "JIR cache was not written";
            assert os.path.getmtime(cache_path) > os.path.getmtime(jac_file) , (
                "cache must be newer than source for the mtime fast path to apply"
            );
            assert is_module_cache_valid(jac_file, cache_path) , (
                "fresh cache should be valid"
            );

            stale = cache_path.read_bytes();
            assert _cached_pins(stale).get("helper_fn", "") == "" , (
                "the pre-edit placement summary should carry no pin"
            );
            with open(toml_path, "a") as f {
                f.write('\n[placement.pins]\n"m.helper_fn" = "server"\n');
            }
            assert not is_module_cache_valid(jac_file, cache_path) , (
                "a jac.toml pins edit must invalidate the module cache"
            );

            assert compiler.get_bytecode(jac_file, JacProgram()) is not None;
            assert cache_path.read_bytes() != stale , (
                "a recompile must overwrite the stale cache entry"
            );
            assert is_module_cache_valid(jac_file, cache_path) , (
                "the rewritten cache must be valid under the new pins"
            );
            assert _cached_pins(cache_path.read_bytes()).get("helper_fn") == "server" , (
                "the recompiled placement summary must honor the new pin"
            );
        } finally {
            if cache_path.exists() {
                cache_path.unlink();
            }
        }
    }
}

test "stub module cache key is source focused" {
    import from jaclang.compiler.driver.jir {
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
        jac_probe = stub_file[:-4] + ".jac";
        with open(jac_probe, "w") as jac_tmp {
            jac_tmp.write("class KeyProbe:\n    k: int\n");
        }
        try {
            jac_key = compute_module_key(jac_probe);
        } finally {
            os.unlink(jac_probe);
        }
        assert stub_key != jac_key , (
            "a project module's key folds in placement/client config; "
            "a stub's key must not"
        );
    } finally {
        os.unlink(stub_file);
    }
}

test "a facade stub knits star imports with overloads in every process" {
    # Regression: symbols a stub absorbs via `from X import *` have their defn
    # nodes in the foreign module's AST, which JIR serialization can only mark
    # EXTERNAL_REF; on read the reader dropped them, so a warm-cached facade
    # stub (e.g. os/path.pyi) lost every re-exported name and its overload
    # chain -- os.path.abspath(str) then failed E1053 against the first
    # overload only.
    absorb_dir = tempfile.mkdtemp(prefix="jac_absorb_knit_", dir=_test_tmp_dir);
    base_file = os.path.join(absorb_dir, "knit_base.pyi");
    facade_file = os.path.join(absorb_dir, "knit_facade.pyi");
    with open(base_file, "w") as f {
        f.write(
            "from typing import overload\n"
                + "@overload\n"
                + "def probe(x: int) -> int: ...\n"
                + "@overload\n"
                + "def probe(x: str) -> str: ...\n"
        );
    }
    with open(facade_file, "w") as f {
        f.write("from knit_base import *\n");
    }
    past = time.time() - 2;
    os.utime(base_file, (past, past));
    os.utime(facade_file, (past, past));
    try {
        prog1 = JacProgram();
        fresh = prog1.load_dependency_module(facade_file);
        assert fresh.sym_tab.lookup("probe") is not None , (
            "fresh facade stub must absorb probe"
        );
        assert fresh.names_in_scope_overload.get("probe") , (
            "fresh facade stub must absorb probe's overload chain"
        );
        prog2 = JacProgram();
        cached = prog2.load_dependency_module(facade_file);
        assert cached.sym_tab.lookup("probe") is not None , (
            "second process's facade stub lost its absorbed symbols"
        );
        assert cached.names_in_scope_overload.get("probe") , (
            "second process's facade stub lost its absorbed overload chain"
        );
    } finally {
        for p in (base_file, facade_file) {
            os.unlink(p);
        }
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
            assert code is not None , "get_bytecode returned None";
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

test "release compile closure clears source trees, stubs and evaluator" {
    with tempfile.TemporaryDirectory(dir=_test_tmp_dir) as d {
        source_path = os.path.join(d, "source.jac");
        stub_path = os.path.join(d, "types.pyi");
        prog = JacProgram();
        def source_ref -> any {
            source_mod = prog.parse_str("glob value = 1;\n", source_path);
            return weakref.ref(source_mod);
        }
        ast_ref = source_ref();
        prog.parse_str("value: int\n", stub_path);
        prog.get_type_evaluator();
        prog.release_compile_closure();
        gc.collect();
        assert ast_ref() is None , "released AST is still strongly referenced";
        assert prog.find_module(source_path) is None;
        assert prog.find_module(stub_path) is None;
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
            assert prog.find_module(source_path) is not None;
        } finally {
            if old_no_evict is None {
                os.environ.pop("JAC_NO_UNIT_EVICT", None);
            } else {
                os.environ["JAC_NO_UNIT_EVICT"] = old_no_evict;
            }
        }
    }
}

test "release compile closure recreates synthesized types with their catalog" {
    prog = JacProgram();
    ev1 = prog.get_type_evaluator();
    ls1 = ev1.prefetch.literal_string_class;
    assert ls1 is not None;
    prog.release_compile_closure();
    assert prog.type_evaluator is None;
    ev2 = prog.get_type_evaluator();
    ls2 = ev2.prefetch.literal_string_class;
    assert ls2 is not None;
    assert ev1 is not ev2;
    assert ls1.shared is not ls2.shared;
}

test "internal get_bytecode evicts unit AST after compile" {
    # Cold bootstrap used to retain every jaclang module AST in
    # the self-host program hub. After the outermost successful compile+cache
    # write, non-stub ASTs must leave the hub so peak RSS stays near one import
    # closure (+ warm typeshed), not the union of every module ever compiled.
    compiler = JacCompiler();
    prog = JacProgram();
    # Two small, already-shipped jaclang modules (always under jaclang_root →
    # resolve to the self-host program). Force a fresh compile so we exercise the
    # post-compile eviction path rather than a disk-cache hit.
    samples = [
        os.path.join(compiler.selfhost.jaclang_root(), "compiler", "driver", "log.jac"),
        os.path.join(
            compiler.selfhost.jaclang_root(), "compiler", "frontend", "constant.jac"
        )
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
            hub = compiler.selfhost.program.mod.hub;
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
