"""Cross-module na compiles honor the parent's gc options (jaseci-labs/jac#7735).

The import walk once compiled imported na modules under default gc "cycles"
regardless of the parent's na_gc_mode, and its on-disk IR cache was keyed by
source + compiler fingerprint only, so artifacts poisoned across gc modes.
Both paths must yield RC-free IR for a gc-none multi-module program.
"""

import os;
import shutil;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     ENFORCE = ["xmod_gc_entry*", "xmod_gc_lib*"];

def _compile_ir(entry_path: str, gc_mode: str, enforce: list) -> str {
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=entry_path,
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                na_gc_mode=gc_mode,
                nogc_enforce_modules=enforce
            )
        );
        assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
        assert ir is not None and ir.gen.llvm_ir is not None;
        return str(ir.gen.llvm_ir);
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
    }
}

def _staged_entry(tmp: str) -> str {
    for name in ("xmod_gc_entry.na.jac", "xmod_gc_lib.na.jac") {
        shutil.copy(os.path.join(FIXTURES, name), os.path.join(tmp, name));
    }
    return os.path.join(tmp, "xmod_gc_entry.na.jac");
}

test "imported na modules inherit gc none: no RC in multi-module IR" {
    with tempfile.TemporaryDirectory() as tmp {
        ir = _compile_ir(_staged_entry(tmp), "none", ENFORCE);
        assert "__rc_" not in ir , "imported module re-entered the RC world";
    }
}

test "gc-mode change invalidates the cross-module IR cache" {
    with tempfile.TemporaryDirectory() as tmp {
        entry = _staged_entry(tmp);
        cycles_ir = _compile_ir(entry, "cycles", []);
        assert "__rc_" in cycles_ir , "cycles-mode build should carry RC";
        nogc_ir = _compile_ir(entry, "none", ENFORCE);
        assert ("__rc_" not in nogc_ir) , "stale cycles-mode cache leaked into the gc-none build";
    }
}
