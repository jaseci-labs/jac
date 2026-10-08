"""Every native library module implements the interface Python declares for it.

A public name, parameter or member of a module under `runtime/na_stdlib` must
be one the Python stub of the same name declares, and each platform variant of
a module must expose the same surface as its siblings. User code is typed
against the stub on every backend, so anything else could not be named."""

import os;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { native_stdlib_root }
import from jaclang.compiler.native_bindings {
    conformance_mismatches,
    native_library_module_name,
    stub_surface,
    typeshed_stub_path,
    variant_mismatches
}

def library_modules -> list[tuple[str, str]] {
    found: list[tuple[str, str]] = [];
    top = native_stdlib_root() or "";
    for (folder, _dirs, files) in os.walk(top) {
        for name in sorted(files) {
            path = os.path.join(folder, name);
            lib = native_library_module_name(path) if name.endswith(".jac") else None;
            if lib is not None {
                found.append((lib, path));
            }
        }
    }
    return sorted(found);
}

test "every public native library module conforms to its Python interface" {
    prog = JacProgram();
    failures: list[str] = [];
    checked = 0;
    for (lib, path) in library_modules() {
        stub_path = typeshed_stub_path(lib);
        if stub_path is None {
            continue;
        }
        stub_mod = prog.load_dependency_module(stub_path, need_tree=True);
        native_mod = prog.load_dependency_module(path, need_tree=True);
        checked += 1;
        for (_decl, why) in conformance_mismatches(stub_mod, native_mod, prog) {
            failures.append(f"{lib}: {why}");
        }
    }
    assert checked > 40 , f"only {checked} library modules were found";
    assert not failures , "\n".join(failures);
}

test "platform variants of a library module expose one surface" {
    prog = JacProgram();
    failures: list[str] = [];
    top = native_stdlib_root() or "";
    for (folder, _dirs, files) in os.walk(top) {
        for name in sorted(files) {
            if not name.endswith(".jac") {
                continue;
            }
            mod = prog.load_dependency_module(
                os.path.join(folder, name), need_tree=True
            );
            for (_decl, why) in variant_mismatches(mod, prog) {
                failures.append(f"{name}: {why}");
            }
        }
    }
    assert not failures , "\n".join(failures);
}

test "the interface surface follows branches, re-exports and bases" {
    prog = JacProgram();
    posix = prog.load_dependency_module(
        typeshed_stub_path("os.path") or "", need_tree=True
    );
    surface = stub_surface(posix, prog);
    assert "join" in surface and "exists" in surface , sorted(surface.keys());
    sched = prog.load_dependency_module(
        typeshed_stub_path("sched") or "", need_tree=True
    );
    event = stub_surface(sched, prog)["Event"];
    assert "sequence" in event.members , sorted(event.members);
    pathlib = prog.load_dependency_module(
        typeshed_stub_path("pathlib") or "", need_tree=True
    );
    path_decl = stub_surface(pathlib, prog)["Path"];
    assert "parts" in path_decl.members , "members of PurePath are inherited by Path";
}
