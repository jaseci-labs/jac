"""Explicit runtime dependencies must resolve before source is emitted."""

import from jaclang.dist.publish.runtime_vendor { build_runtime_closure }

test "unresolvable extra seed fails loudly" {
    # This exact module was deleted by #7947; the vendorer used to skip the
    # seed silently and exit 0, leaving a backend that dies on first import.
    with testraises(ValueError) as exc {
        build_runtime_closure(
            [], extra_seeds=["jaclang.data.storage.sqlalchemy_memory"]
        );
    }
    assert "sqlalchemy_memory" in str(exc.value);
}

test "vendored runtime modules compile in the server codespace unless native by policy" {
    import from pathlib { Path }
    import from unittest.mock { patch }
    import jaclang.dist.publish.runtime_vendor as vendor;
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.frontend.codeinfo {
        is_native_by_location,
        is_shared_runtime_module
    }
    seen: dict[str, str] = {};
    def record(
        pkg_root: Path,
        path: Path,
        prog: JacProgram,
        native: (dict[str, any] | None) = None,
        native_sources: bool = True
    ) -> str {
        seen[str(path)] = prog.options.default_codespace;
        return "";
    }
    with patch.object(vendor, "_compile_runtime_module", side_effect=record) {
        vendor.build_runtime_closure([]);
    }
    assert seen , "the base runtime closure compiles at least one module";
    for (path, space) in seen.items() {
        policy_native = is_native_by_location(path) or is_shared_runtime_module(path);
        expected = "" if policy_native else "server";
        assert space == expected , f"{path}: {space}";
    }
}

test "source products of package-owned modules come from the compiler's own program" {
    import os;
    import jaclang;
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.source_products { python_source }
    path = os.path.join(
        os.path.dirname(os.path.realpath(str(jaclang.__file__))),
        "runtime",
        "surface.jac"
    );
    program = JacProgram();
    (source, module) = python_source(path, program);
    assert source;
    assert module is not None;
    cache = program._get_compiler().selfhost;
    assert cache.owns(path);
    assert os.path.realpath(path) not in program.mod.hub , (
        "the caller's program must not analyze the compiler's own module"
    );
}

test "the closure carries the runtime a program needs and not the compiler" {
    closure = build_runtime_closure(
        ["import jaclang.lib.jaclib\n"],
        extra_seeds=["jaclang.lib.jaclib", "jaclang.runtime.surface"]
    );
    assert "__init__.py" in closure;
    assert "lib/jaclib.py" in closure;
    assert "runtime/surface.py" in closure;
    assert "compiler/frontend/codeinfo.py" not in closure;
    assert not any(name.startswith("compiler/driver/") for name in closure) , (
        "serving metadata must not pull the compiler into a runtime"
    );
}

test "the closure carries the fixed-width runtime a sized-typed program needs" {
    closure = build_runtime_closure(["import jaclang.runtime.sized\n"]);
    assert "runtime/sized.py" in closure;
    assert "runtime/scalars.py" in closure;
}
