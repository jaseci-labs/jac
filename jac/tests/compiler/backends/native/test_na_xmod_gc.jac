"""Cross-module na compiles honor the parent's gc options (jaseci-labs/jac#7735).

The import walk once compiled imported na modules under default gc "cycles"
regardless of the parent's na_gc_mode, and its on-disk IR cache was keyed by
source + compiler fingerprint only, so artifacts poisoned across gc modes.
Both paths must yield RC-free IR for a gc-none multi-module program.
"""

import os;
import from jaclang.compiler.driver.compile_options {
    push_native_target,
    pop_native_target
}
import shutil;
import subprocess;
import sys;
import tempfile;
import jaclang;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     ENFORCE = ["xmod_gc_entry*", "xmod_gc_lib*"];

def _compile_ir(entry_path: str, gc_mode: str, enforce: list) -> str {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=entry_path,
            options=CompileOptions(
                aot_mode=True, na_gc_mode=gc_mode, memory_enforce=enforce
            )
        );
        assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
        assert ir is not None and ir.gen.llvm_ir is not None;
        return str(ir.gen.llvm_ir);
    } finally {
        pop_native_target(prev);
    }
}

def _staged_entry(tmp: str) -> str {
    for name in ("xmod_gc_entry.jac", "xmod_gc_lib.jac") {
        shutil.copy(os.path.join(FIXTURES, name), os.path.join(tmp, name));
    }
    return os.path.join(tmp, "xmod_gc_entry.jac");
}

test "imported na modules inherit gc none: no RC in multi-module IR" {
    with tempfile.TemporaryDirectory() as tmp {
        ir = _compile_ir(_staged_entry(tmp), "none", ENFORCE);
        assert "__rc_" not in ir , "imported module re-entered the RC world";
    }
}

test "host-path multi-module gc none build passes assert-no-rc" {
    with tempfile.TemporaryDirectory() as tmp {
        `entry = _staged_entry(tmp);
        src_root = os.path.dirname(os.path.dirname(os.path.abspath(jaclang.__file__)));
        with open(os.path.join(tmp, "jac.toml"), "w") as f {
            f.write("[project]\nname = \"xmodgc\"\n\n[memory]\nprofile = \"nogc\"\n\n");
            f.write(f"[dev]\njaclang_source = \"{src_root}\"\n");
        }
        out_bin = os.path.join(tmp, "xmod.bin");
        comp = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "build",
                "--native",
                `entry,
                "--memory",
                "nogc",
                "-o",
                out_bin
            ],
            capture_output=True,
            text=True,
            timeout=300,
            cwd=tmp
        );
        combined = (comp.stdout or "") + (comp.stderr or "");
        assert comp.returncode == 0 , f"multi-module host build kept RC machinery: {combined[-900:]}";
    }
}

test "gc-mode change invalidates the cross-module IR cache" {
    with tempfile.TemporaryDirectory() as tmp {
        `entry = _staged_entry(tmp);
        cycles_ir = _compile_ir(`entry, "cycles", []);
        assert "__rc_" in cycles_ir , "cycles-mode build should carry RC";
        nogc_ir = _compile_ir(`entry, "none", ENFORCE);
        assert ("__rc_" not in nogc_ir) , "stale cycles-mode cache leaked into the gc-none build";
    }
}
