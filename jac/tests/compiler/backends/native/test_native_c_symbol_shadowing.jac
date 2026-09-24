"""User definitions may share a name with a C symbol the program links against.

A native program is one flat link namespace. `import math` declares libm's
`floor` through the bundled `_math_native` module, so a user `def floor` in the
same module used to die in native lowering (`DuplicatedNameError: floor`) and
fall back to the server codespace. Without the import the collision was
silent instead: the backend's own `floor` extern (behind
`float.as_integer_ratio`) bound to the user function. A user definition named
after a C symbol is now emitted as `__jac_def_<name>`, beside the C one.
"""
import ctypes;
import os;
import re;
import subprocess;
import tempfile;
import jaclang;
import from tests.support {
    compile_native,
    compile_native_ir,
    get_func,
    jac_command,
    TESTS_DIR
}
import from jaclang.compiler.frontend.codeinfo {
    NATIVE_RESERVED_C_SYMBOLS,
    native_def_symbol,
    native_stdlib_root
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     EXPECTED_LINES: list[str] = ["7 2 104.0 4.0", "3 8.0 99 3", "11 5"];

test "a user floor, sqrt and glob pow coexist with the math module natively" {
    (engine, _module) = compile_native("c_symbol_shadowing.jac");
    assert get_func(engine, "user_floor_probe", ctypes.c_int64)() == 7;
    assert get_func(engine, "math_floor_probe", ctypes.c_int64)() == 2;
    assert get_func(engine, "user_sqrt_probe", ctypes.c_double)() == 104.0;
    assert get_func(engine, "math_sqrt_probe", ctypes.c_double)() == 4.0;
    assert get_func(engine, "glob_pow_probe", ctypes.c_int64)() == 3;
    assert get_func(engine, "math_pow_probe", ctypes.c_double)() == 8.0;
}

test "user strlen, puts and main do not replace the runtime's C symbols" {
    (engine, _module) = compile_native("c_symbol_shadowing.jac");
    assert get_func(engine, "strlen_probe", ctypes.c_int64)() == 11099;
    assert get_func(engine, "entry_names_probe", ctypes.c_int64)() == 1105;
}

test "C-named user definitions get Jac-owned symbols and C keeps its own" {
    module = compile_native_ir("c_symbol_shadowing.jac");
    text = str(module.gen.llvm_ir);
    for name in ["floor", "sqrt", "strlen", "puts", "main"] {
        assert re.search(rf'define [^\n]*@"?__jac_def_{name}"?\(', text) , (
            f"user {name} was not emitted under its Jac-owned symbol"
        );
        assert not re.search(rf'define [^\n]*@"?{name}"?\(', text) , (
            f"a user definition took over the C symbol {name}"
        );
    }
    assert re.search(r'@"?__jac_def_pow"? = ', text) , "glob pow kept the C name";
    assert re.search(r'declare [^\n]*@"?floor"?\(double', text) , (
        "libm floor is no longer declared for math.floor"
    );
}

test "the backend's own floor extern does not bind to a user floor" {
    (engine, _module) = compile_native("c_symbol_shadowing_ratio.jac");
    assert get_func(engine, "ratio_probe", ctypes.c_int64)() == 52;
    assert get_func(engine, "user_floor_probe", ctypes.c_double)() == 1.5;
}

test "C-named definitions imported from a separately compiled module bind correctly" {
    (engine, _module) = compile_native("c_symbol_shadowing_xmod.jac");
    assert get_func(engine, "imported_floor_probe", ctypes.c_int64)() == 8;
    assert get_func(engine, "math_floor_probe", ctypes.c_int64)() == 3;
    assert get_func(engine, "imported_ceil_probe", ctypes.c_double)() == 15.0;
    assert get_func(engine, "math_ceil_probe", ctypes.c_int64)() == 2;
    assert get_func(engine, "imported_glob_probe", ctypes.c_int64)() == 9;
    assert get_func(engine, "math_exp_probe", ctypes.c_double)() == 1.0;
}

test "jac run keeps a module with a user floor and import math native" {
    proc = subprocess.run(
        jac_command("run", os.path.join(FIXTURES, "c_symbol_shadowing.jac")),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , proc.stderr[-800:];
    assert "server codespace" not in proc.stderr , proc.stderr[-800:];
    assert [
        line
        for line in proc.stdout.splitlines()
        if line.strip()
    ]
        == EXPECTED_LINES , proc.stdout;
}

test "a native binary links a user main, puts and floor beside libc and libm" {
    out_bin = os.path.join(tempfile.mkdtemp(), "c_symbol_shadowing.bin");
    build = subprocess.run(
        jac_command(
            "build",
            "--native",
            os.path.join(FIXTURES, "c_symbol_shadowing.jac"),
            "-o",
            out_bin
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert build.returncode == 0 , build.stderr[-900:];
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , proc.stderr[-400:];
    assert [
        line
        for line in proc.stdout.splitlines()
        if line.strip()
    ]
        == EXPECTED_LINES , proc.stdout;
}

test "native_def_symbol moves only C-named definitions" {
    assert native_def_symbol("/tmp/app.jac", "floor") == "__jac_def_floor";
    assert native_def_symbol("", "sqrt") == "__jac_def_sqrt";
    assert native_def_symbol("/tmp/app.jac", "floorish") == "floorish";
    stdlib = native_stdlib_root();
    if stdlib is not None {
        library_symbol = native_def_symbol(os.path.join(stdlib, "math.jac"), "floor");
        assert library_symbol.startswith("__jac_lib_") , library_symbol;
    }
}

test "every C symbol the backend or a bundled module declares is reserved" {
    # Drift guard: a new extern the backend declares, or a new C function a
    # bundled na_stdlib module imports, must join NATIVE_RESERVED_C_SYMBOLS,
    # or a user definition of that name collides with it again.
    package_dir = os.path.dirname(jaclang.__file__);
    declared: dict[str, str] = {};
    backend = os.path.join(package_dir, "compiler", "backends", "native");
    for (directory, _dirs, files) in os.walk(backend) {
        for file_name in files {
            if not file_name.endswith(".jac") {
                continue;
            }
            path = os.path.join(directory, file_name);
            with open(path) as handle {
                source = handle.read();
            }
            for found in re.finditer(
                r'_get_or_declare_extern\(\s*"([A-Za-z_]\w*)"', source
            ) {
                declared[found.group(1)] = path;
            }
        }
    }
    stdlib = native_stdlib_root();
    assert stdlib is not None , "bundled na_stdlib not found";
    for (directory, _dirs, files) in os.walk(stdlib) {
        for file_name in files {
            if not file_name.endswith(".jac") {
                continue;
            }
            path = os.path.join(directory, file_name);
            with open(path) as handle {
                source = handle.read();
            }
            for block in re.finditer(r'import\s+from\s+[^{};]+\{([^{}]*)\}', source) {
                for found in re.finditer(
                    r'\bdef\s+([A-Za-z_]\w*)\s*\(', block.group(1)
                ) {
                    declared[found.group(1)] = path;
                }
            }
        }
    }
    assert "floor" in declared and "strlen" in declared , "drift scan found nothing";
    missing = sorted(
        f"{name} ({os.path.relpath(path, package_dir)})"
        for (name, path) in declared.items()
        if name not in NATIVE_RESERVED_C_SYMBOLS
    );
    assert not missing , (
        "C symbols missing from NATIVE_RESERVED_C_SYMBOLS: " + ", ".join(missing)
    );
}
