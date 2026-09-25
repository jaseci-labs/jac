"""A native build holds every unit's lowered tree until the build ends.

`NativeBuildSession._finish` optimizes, emits and persists one unit at a
time, but each unit's lowered module (its syntax tree plus the generated
LLVM IR on `gen.llvm_ir`) stays in `session.lowered` until `close()` runs
after the last unit. Peak memory for a many-module build therefore holds
every unit at once, even though a unit's products are on disk and in the
registry once it has been persisted.

The test drives the session the way `build_link_plan` does, but persists the
dependency on its own first, so it can check whether the dependency's tree
is still alive while the build is in progress. The sources are written to a
tempdir so both units are always lowered in this session, never served from
the cache.
"""

import gc;
import os;
import tempfile;
import weakref;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.nativecache { NativeBuildSession }
import from jaclang.compiler.backends.native.link_plan { build_link_plan }

glob DEP_SRC = "def sr_scale(n: int) -> int {\n    return n * 3;\n}\n",
     MAIN_SRC = (
         "import from session_release_dep { sr_scale }\n\n"
         "def sr_use(n: int) -> int {\n    return sr_scale(n) + 1;\n}\n"
     );

def write_source(tmp: str, name: str, text: str) -> str {
    path = os.path.join(tmp, name);
    with open(path, "w", encoding="utf-8") as fh {
        fh.write(text);
    }
    return os.path.realpath(path);
}

test "a persisted unit's lowered tree is released before the build ends" {
    with tempfile.TemporaryDirectory() as tmp {
        dep = write_source(tmp, "session_release_dep.jac", DEP_SRC);
        main = write_source(tmp, "session_release_main.jac", MAIN_SRC);
        opts = CompileOptions(
            aot_mode=True,
            default_codespace="native",
            force_target_program=True,
            skip_native_engine=True
        );
        prog = JacProgram();
        registry = prog.native_units();
        session = NativeBuildSession(registry=registry, options=opts);
        registry.session = session;
        alive_after_persist = False;
        try {
            plan = build_link_plan(prog, [main], opts);
            paths = [unit.path for unit in plan.units];
            assert dep in session.lowered , (
                f"the dependency was not lowered in this session: {sorted(
                    session.lowered
                )}"
            );
            dep_ref = weakref.ref(session.lowered[dep]);
            session.finish([dep]);
            dep_entry = registry.entries.get(dep);
            assert dep_entry is not None and dep_entry.bitcode is not None , (
                "the dependency's products were not recorded after finish"
            );
            gc.collect();
            alive_after_persist = dep_ref() is not None;
            session.finish(
                [
                    path
                    for path in paths
                    if path != dep
                ]
            );
        } finally {
            registry.session = None;
            session.close();
        }
        gc.collect();
        assert dep_ref() is None , (
            "the dependency's tree is still alive after the session closed; "
            "something outside the session pins it"
        );
        assert not alive_after_persist , (
            "the dependency's lowered tree (and its gen.llvm_ir) stays alive "
            "after its products were persisted, until the whole build ends; "
            "a many-module build holds every unit in memory at once"
        );
    }
}
