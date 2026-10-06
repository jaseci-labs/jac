"""Same-named classes in two jaclang-package modules are distinct native types.

User modules scope each archetype's native identity by its defining module
(`codeinfo.native_arch_name`), but every module of the jaclang package kept
its bare name, since the backend and the host address toolchain classes by
name. JacPython's runtime and the bundled stdlib live in that package, so two
of its modules each defining `obj CompressorState` shared one LLVM struct:
`jac check` warned `native struct name collision ... skipping
re-registration` and the importer lowered one module's class with the other's
layout. Bare names are now kept only where something binds them by name (the
language runtime, the type stubs and the native compiler's own scope); the
rest of the package is scoped like any program.

The fixture is a `jac.toml` project inside the package. Such a project was
exempt from nogc enforcement, as if it were toolchain code, so its nogc build
emitted the reference-counted runtime; it now builds under every profile.
"""

import os;
import jaclang;
import from tests.support { assert_native_identity }
import from jaclang.compiler.frontend.codeinfo {
    is_toolchain_unit,
    native_arch_display,
    native_arch_name
}

glob PACKAGE = os.path.dirname(jaclang.__file__),
     FIXTURES = os.path.join(
         PACKAGE, "compiler", "tests", "fixtures", "same_named_classes"
     );

test "package modules outside the bound set scope their classes" {
    bz2 = os.path.join(PACKAGE, "runtime", "python", "modules", "bz2.jac");
    zstd = os.path.join(PACKAGE, "runtime", "python", "modules", "zstd.jac");
    bz_name = native_arch_name(bz2, "CompressorState");
    zs_name = native_arch_name(zstd, "CompressorState");
    assert bz_name != zs_name , bz_name;
    assert native_arch_display(bz_name) == "CompressorState";
    assert native_arch_display(zs_name) == "CompressorState";
    stdlib = os.path.join(PACKAGE, "runtime", "na_stdlib", "pathlib.jac");
    assert native_arch_name(stdlib, "Path") != "Path";
}

test "the runtime, type stubs and the native compiler keep bare names" {
    kernel = os.path.join(PACKAGE, "runtime", "osp_kernel.jac");
    assert native_arch_name(kernel, "OspRuntime") == "OspRuntime";
    archetypes = os.path.join(PACKAGE, "runtime", "archetype.jac");
    assert native_arch_name(archetypes, "Root") == "Root";
    builtins = os.path.join(PACKAGE, "vendor", "typeshed", "stdlib", "builtins.pyi");
    assert native_arch_name(builtins, "dict") == "dict";
    unitree = os.path.join(PACKAGE, "compiler", "frontend", "unitree.jac");
    assert native_arch_name(unitree, "Module") == "Module";
}

test "a jac.toml project inside the package is a program, not the toolchain" {
    kernel = os.path.join(PACKAGE, "runtime", "osp_kernel.jac");
    assert is_toolchain_unit(kernel);
    assert not is_toolchain_unit(os.path.join(FIXTURES, "main.jac")) , (
        "a project nested in the package must lower like any program under nogc"
    );
}

test "two package modules' same-named classes keep their own layouts" {
    out = assert_native_identity(os.path.join(FIXTURES, "main.jac"));
    assert out.split("\n")[0] == "bz:9:False 2:7:0.25" , out;
    assert "True False True" in out , out;
}
