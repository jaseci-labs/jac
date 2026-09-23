"""Cached native modules must restore foreign libraries in a fresh process."""
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command }
import from jaclang.compiler.driver.compiler { JacCompiler }
import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }

test "cold and warm native imports load their transitive C libraries" {
    cc = shutil.which("cc");
    if cc is None or sys.platform == "win32" {
        import unittest;
        raise unittest.SkipTest("Requires a Unix C compiler");
    }
    with tempfile.TemporaryDirectory(prefix="jac-clib-cache-") as directory {
        project_dir = Path(directory);
        vendor = project_dir / "vendor";
        vendor.mkdir();
        source = project_dir / "probe.c";
        source.write_text("int cached_answer(void) { return 42; }\n");
        library = vendor
            / (
                "libcacheprobe.dylib"
                    if sys.platform == "darwin"
                    else "libcacheprobe.so"
            );
        flags = ["-dynamiclib"] if sys.platform == "darwin" else ["-shared", "-fPIC"];
        subprocess.run([cc, *flags, str(source), "-o", str(library)], check=True);
        (project_dir / "foreign.jac").write_text(
            "import from vendor.cacheprobe { def cached_answer() -> i32; }\n"
            "def value() -> int { return int(cached_answer()); }\n"
        );
        (project_dir / "outer.jac").write_text(
            "import from foreign { value }\n"
            "def answer() -> int { return value(); }\n"
        );
        fixture = project_dir / "checks.jac";
        fixture.write_text(
            "import from foreign { value }\n"
            "import from outer { answer }\n"
            "test \"direct\" { assert value() == 42; }\n"
            "test \"transitive\" { assert answer() == 42; }\n"
        );
        # The first process loads the C library while compiling. Only a new
        # process can expose missing library restoration on the cache path.
        for attempt in range(3) {
            result = subprocess.run(
                jac_command("test", str(fixture), "-j0"),
                cwd=directory,
                capture_output=True,
                text=True,
                timeout=300
            );
            output = result.stdout + result.stderr;
            assert result.returncode == 0 , f"run {attempt}: {result.returncode}\n{output}";
            assert "2 passed" in output , output;
            assert "recompiling" not in output , output;
        }
    }
}

test "native cache rejects absent library metadata" {
    compiler = JacCompiler();
    for metadata in [None, {}] {
        caught = False;
        try {
            compiler._restore_native_clibs(CodeGenTarget(), metadata);
        } except ValueError {
            caught = True;
        }
        assert caught , "Legacy cache entries must fall back to recompilation";
    }
}

test "native cache preserves library metadata for dependent compilation" {
    gen = CodeGenTarget();
    JacCompiler()._restore_native_clibs(
        gen,
        {
            "clib_paths": ["libfixture.so"],
            "clib_symbol_lib": {"answer": "libfixture.so"},
            "exported_symbols": ["value"]
        }
    );
    assert gen._clib_paths == ["libfixture.so"];
    assert gen._clib_symbol_lib == {"answer": "libfixture.so"};
    assert gen._exported_symbols == ["value"];
}
