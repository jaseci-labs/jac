"""Regression coverage for lazy-singleton narrowing (issue #7165).

The lazy-singleton idiom guards an optional module global (or object attribute)
with `if slot is None { slot = init(); }` and then `return slot`. When `init()`
has a precise type the assignment narrows the slot to its non-`None` form and
the return type-checks. When `init()` is imprecise -- `json.loads`, a call into
an installed-but-untyped third-party package (foreign `Any`) -- the assignment
still writes a concrete value, so the slot is no longer `None` on that path.

The narrowing engine used to *discard* the narrow for an `Any` initializer and
fall back to the declared `T | None`, which then surfaced two statements later
as a confusing `Cannot return T | NoneType, expected T` (E1002). This pins that
the assignment-based narrow removes `None` for an imprecise initializer, so the
return no longer cascades -- while a genuinely incompatible concrete initializer
is still reported at the assignment site (E1001), not silently swallowed.
"""

import os;
import sys;
import shutil;
import tempfile;
import importlib;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.bccache { discover_base_file }

glob BATCH_DIR = str(
         Path(jaclang.__file__).parent / "compiler" / "tests" / "fixtures" / "global_narrowing"
     );


"""Type-check `files` in one program the way `jac check` batches a run.

Mirrors the CLI's per-file loop: an impl annex is resolved back to its base
module and every entry is compiled into the shared program with
`force_target_program` so they land in one hub. Returns the emitted messages.
"""
def check_batch(files: list[str]) -> list[str] {
    prog = JacProgram();
    for rel in files {
        file_path = os.path.join(BATCH_DIR, rel);
        base_path = discover_base_file(file_path);
        if base_path is not None {
            file_path = base_path;
        }
        prog.compile(
            file_path=file_path,
            options=CompileOptions(
                type_check=True, no_cgen=True, force_target_program=True
            )
        );
    }
    return [str(e) for e in prog.errors_had];
}


"""Keep only the return-slot cascade this issue is about (`NoneType, expected`)."""
def return_cascades(errors: list[str]) -> list[str] {
    return [
        e
        for e in errors
        if "NoneType, expected" in e
    ];
}


"""Type-check `src` with `search_dir` visible on `sys.path`."""
def check_src(src: str, search_dir: str) -> JacProgram {
    try {
        sys.path.insert(0, search_dir);
        importlib.invalidate_caches();
        prog = JacProgram();
        prog.compile(file_path="gn_src.jac", use_str=src, type_check=True);
        return prog;
    } finally {
        if search_dir in sys.path {
            sys.path.remove(search_dir);
        }
        importlib.invalidate_caches();
        sys.modules.pop("untyped_client", None);
    }
}


test "batch: explicit-Any singleton does not cascade into a return error" {
    errors = check_batch(
        ["service.jac", os.path.join("impl", "service.impl.jac"), "consumer.jac"]
    );
    assert return_cascades(errors) == [] , errors;
}


test "each pair of the singleton batch is cascade-free" {
    impl_rel = os.path.join("impl", "service.impl.jac");
    assert return_cascades(check_batch(["service.jac", "consumer.jac"])) == [];
    assert return_cascades(check_batch([impl_rel, "consumer.jac"])) == [];
    assert return_cascades(check_batch(["service.jac", impl_rel])) == [];
}


test "foreign-Any singleton from an untyped third-party call checks clean" {
    base_dir = tempfile.mkdtemp(prefix="jac_gn_");
    try {
        sp = os.path.join(base_dir, "site-packages");
        pkg_dir = os.path.join(sp, "untyped_client");
        os.makedirs(pkg_dir, exist_ok=True);
        with open(os.path.join(pkg_dir, "__init__.py"), "w") as f {
            f.write("def connect():\n    return {}\n");
        }

        src = "import untyped_client;\n"
        "\n"
        "glob _conn: (dict[str, int] | None) = None;\n"
        "\n"
        "def get_conn -> dict[str, int] {\n"
        "    if _conn is None {\n"
        "        _conn = untyped_client.connect();\n"
        "    }\n"
        "    return _conn;\n"
        "}\n";
        prog = check_src(src, sp);
        errors = [str(e) for e in prog.errors_had];
        assert errors == [] , errors;
    } finally {
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}


test "control: an incompatible concrete initializer is still reported" {
    errors = check_batch(["mismatch.jac"]);
    assert any("Bar" in e for e in errors) , errors;
}
