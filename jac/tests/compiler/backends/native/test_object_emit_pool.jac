"""Object emission for a link runs on a pool and changes nothing but the time.

A link in objects mode emits each unit's object from its bitcode. The units
are independent, and emitting them one after another was most of the link
step of a kernel build: about two minutes of a cold build on a laptop, five
on a CI runner. Each emission now parses its bitcode into its own LLVM
context, so a thread pool can run them side by side.
"""

import os;
import from pathlib { Path }
import jaclang.compiler.driver.jir as jir;
import from jaclang.compiler.backends.native.kernel_resolve { kernel_options }
import from jaclang.compiler.backends.native.link_plan { build_link_plan }
import from jaclang.compiler.backends.native.na_compile_pass {
    emit_unit_object,
    emit_unit_objects,
    object_emit_jobs
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

glob PKG: Path = Path(str(jir.__file__)).resolve().parent.parent.parent,
     LEAVES: tuple[str, ...] = (
         "compiler/types/ct_int.jac",
         "compiler/types/stubcat/format.jac",
         "project/app_kinds.jac",
         "runtime/osp_tag.jac"
     ),
     JOB_ENV: tuple[str, ...] = ("JAC_NATIVE_EMIT_JOBS", "JAC_JOBS");

"""Lower leaf units of the real compiler, whatever the cache holds, and leave
their objects unemitted."""
def lowered_plan -> tuple[JacProgram, CompileOptions, list[str]] {
    program = JacProgram();
    options = kernel_options();
    options.no_ir_cache = True;
    plan = build_link_plan(
        program, [str(PKG / rel) for rel in LEAVES], options, native_unit=True
    );
    return (program, options, [unit.path for unit in plan.units]);
}

def unit_bitcodes(
    program: JacProgram, options: CompileOptions, paths: list[str]
) -> list[bytes] {
    found: list[bytes] = [];
    for path in paths {
        bitcode = program.native_units().bitcode_for(path, options);
        assert bitcode is not None , f"{path} has no bitcode";
        found.append(bitcode);
    }
    return found;
}

def with_jobs(settings: dict[str, str]) -> dict[str, (str | None)] {
    saved: dict[str, (str | None)] = {};
    for name in JOB_ENV {
        saved[name] = os.environ.pop(name, None);
    }
    os.environ.update(settings);
    return saved;
}

def restore_jobs(saved: dict[str, (str | None)]) {
    for (name, value) in saved.items() {
        if value is None {
            os.environ.pop(name, None);
        } else {
            os.environ[name] = value;
        }
    }
}

test "objects emitted on a pool are the objects emitted one at a time" {
    (program, options, paths) = lowered_plan();
    bitcodes = unit_bitcodes(program, options, paths);
    assert len(bitcodes) >= len(LEAVES);
    serial = [emit_unit_object(bitcode, options) for bitcode in bitcodes];
    saved = with_jobs({"JAC_NATIVE_EMIT_JOBS": "4"});
    try {
        assert object_emit_jobs() == 4;
        assert emit_unit_objects(bitcodes, options) == serial;
        assert emit_unit_objects(bitcodes * 6, options) == serial * 6 , (
            "a pooled emission returned objects out of order or changed one"
        );
    } finally {
        restore_jobs(saved);
    }
}

test "a link emits each pending object once and keeps it" {
    (program, options, paths) = lowered_plan();
    registry = program.native_units();
    events = program.analysis.cache_events;
    saved = with_jobs({"JAC_NATIVE_EMIT_JOBS": "4"});
    try {
        for path in paths {
            registry.entries[os.path.realpath(path)].object_bytes = None;
        }
        before = events.get("native_object_emit", 0);
        registry.emit_objects(paths, options);
        emitted = events.get("native_object_emit", 0) - before;
        assert emitted == len(paths) , f"{emitted} objects for {len(paths)} units";
        registry.emit_objects(paths, options);
        assert events.get("native_object_emit", 0) - before == emitted , (
            "an object that was already emitted was emitted again"
        );
        for (path, bitcode) in zip(paths, unit_bitcodes(program, options, paths)) {
            assert registry.object_for(path, options)
                == emit_unit_object(bitcode, options);
        }
    } finally {
        restore_jobs(saved);
    }
}

test "the job count follows the environment and never drops below one" {
    saved = with_jobs({});
    try {
        assert 1 <= object_emit_jobs() <= 8;
        os.environ["JAC_JOBS"] = "0";
        assert object_emit_jobs() == 1 , "JAC_JOBS=0 asks for serial work";
        os.environ["JAC_JOBS"] = "auto";
        assert 1 <= object_emit_jobs() <= 8;
        os.environ["JAC_NATIVE_EMIT_JOBS"] = "3";
        assert object_emit_jobs() == 3 , "the specific setting wins over JAC_JOBS";
    } finally {
        restore_jobs(saved);
    }
}
