"""Cached native modules must restore foreign libraries in a fresh process."""
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from tests.support { jac_command, compiler_python_command }
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
            if attempt == 2 {
                # Exercise the legacy textual-IR path in a fresh process too.
                convert = """
import struct, zlib
from pathlib import Path
from jaclang.compiler.driver.jir import (
    read_sections, write_sections,
    SECTIONS_MAGIC, HEADER_SIZE, SEC_NATIVE_OBJ, SEC_LLVM_IR,
)
from jaclang.compiler.backends.native.llvm import binding as llvm
converted_count = 0
for cache in Path('.jac/cache').rglob('*.jir'):
    data = cache.read_bytes()
    pos = data.find(SECTIONS_MAGIC, HEADER_SIZE)
    assert pos >= 0
    sections = read_sections(data, pos + len(SECTIONS_MAGIC))
    if SEC_NATIVE_OBJ not in sections:
        continue
    payload = sections.pop(SEC_NATIVE_OBJ)
    size = struct.unpack_from('<H', payload)[0]
    sections[SEC_LLVM_IR] = zlib.compress(
        str(llvm.parse_bitcode(payload[2 + size:])).encode()
    )
    cache.write_bytes(data[:pos] + write_sections(sections))
    converted_count += 1
assert converted_count >= 2, converted_count
""";
                converted = subprocess.run(
                    compiler_python_command(convert),
                    cwd=directory,
                    capture_output=True,
                    text=True,
                    timeout=300
                );
                assert converted.returncode == 0 , converted.stdout + converted.stderr;
            }
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

test "native cache rejects absent library metadata and missing libraries" {
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
    with patch(
        "jaclang.compiler.backends.native.na_compile_pass.load_jit_clib",
        return_value=False
    ) {
        caught = False;
        try {
            compiler._restore_native_clibs(
                CodeGenTarget(), {"clib_paths": ["missing-library"]}
            );
        } except ValueError {
            caught = True;
        }
        assert caught , "Do not publish an engine with unresolved libraries";
    }
}

test "native cache preserves library metadata for dependent compilation" {
    gen = CodeGenTarget();
    with patch(
        "jaclang.compiler.backends.native.na_compile_pass.load_jit_clib",
        return_value=True
    ) as loader {
        JacCompiler()._restore_native_clibs(
            gen,
            {
                "clib_paths": ["libfixture.so"],
                "clib_symbol_lib": {"answer": "libfixture.so"},
                "exported_symbols": ["value"]
            }
        );
        loader.assert_called_once_with("libfixture.so");
    }
    assert gen._clib_paths == ["libfixture.so"];
    assert gen._clib_symbol_lib == {"answer": "libfixture.so"};
    assert gen._exported_symbols == ["value"];
}
