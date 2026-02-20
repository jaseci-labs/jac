"""Tests for Jac Loader."""

import io;
import os;
import sys;
import subprocess;
import marshal;
import shutil;
import tempfile;
import time;
import from pathlib { Path }
import jaclang;
import from jaclang { JacRuntime as Jac }
import from jaclang { JacRuntimeInterface }
import from jaclang.cli.commands { execution }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.bccache { CacheKey, DiskBytecodeCache }
import from jaclang.jac0core.compiler { JacCompiler }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     TEST_DIR = os.path.join(JAC_ROOT, "tests", "compiler"),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "fixtures"),
     LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

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
    assert "/tests/compiler/fixtures/hello_world.jac" in str(Jac.loaded_modules).replace(
        "\\\\", "/"
    );
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
        "{SomeObj(a=10): 'check'} [MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]" in stdout_value
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
        "{SomeObj(a=10): 'check'} [MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]" in stdout_value
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
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp_file {
        tmp_file.write('with entry { "hello" :> print; }\n');
        user_file = tmp_file.name;
    }

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
    }
}

test "get bytecode returns cache when llvmir missing" {
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp {
        tmp.write("glob x = 1;\n");
        tmp.flush();
        jac_file = tmp.name;
    }

    past = time.time() - 2;
    os.utime(jac_file, (past, past));

    try {
        cache = DiskBytecodeCache();
        cache._cache_dir = Path(tempfile.mkdtemp());
        compiler = JacCompiler(bytecode_cache=cache);

        code1 = compiler.get_bytecode(jac_file, JacProgram());
        assert code1 is not None , "First compilation should succeed";

        key = CacheKey.for_source(jac_file);
        assert cache.get(key) is not None , "Bytecode should be cached";
        assert cache.get_llvmir(key) == "" , "LLVM IR should be cached as empty string";

        cache._get_llvmir_cache_path(key).unlink();
        assert cache.get_llvmir(key) is None , "LLVM IR cache should be gone";

        code2 = compiler.get_bytecode(jac_file, JacProgram());
        assert code2 is not None , "Should return cached bytecode";
        assert marshal.dumps(code1) == marshal.dumps(code2);
    } finally {
        os.unlink(jac_file);
        shutil.rmtree(str(cache._cache_dir), ignore_errors=True);
    }
}
