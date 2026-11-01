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
import tempfile;
import jaclang;
import from jaclang.compiler.backends.native.mir.emit {
    RELEASE_ACYCLIC_SYMBOL,
    RELEASE_SYMBOL,
    RETAIN_SYMBOL
}
import from tests.support {
    diagnostics_text,
    jac_command,
    kernel_compile_file,
    TESTS_DIR
}
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     ENFORCE = ["xmod_gc_entry*", "xmod_gc_lib*"];

"""The LLVM IR the kernel emitted for the staged program: the entry's unit
and the imported module's."""
def _compile_ir(entry_path: str, gc_mode: str, enforce: list[any]) -> str {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        result = kernel_compile_file(
            entry_path,
            CompileOptions(
                aot_mode=True,
                na_gc_mode=gc_mode,
                memory_enforce=enforce,
                skip_native_engine=True
            ),
            ["mir"]
        );
        assert result.ok() , diagnostics_text(result);
        staged = os.path.dirname(os.path.realpath(entry_path));
        texts = [
            unit.native_ir
            for unit in result.units
            if unit.native_ir and os.path.dirname(unit.path) == staged
        ];
        assert len(texts) == 2 , f"expected the entry and its import native, got {len(texts)}";
        return "\n".join(texts);
    } finally {
        pop_native_target(prev);
    }
}

"""Whether `ir` calls into the reference-counting runtime."""
def _carries_rc(ir: str) -> bool {
    return "__rc_" in ir
        or any(
            symbol in ir
            for symbol in (RETAIN_SYMBOL, RELEASE_SYMBOL, RELEASE_ACYCLIC_SYMBOL)
        );
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
        assert not _carries_rc(ir) , "imported module re-entered the RC world";
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
            jac_command("build", "--native", `entry, "--memory", "nogc", "-o", out_bin),
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
        assert _carries_rc(cycles_ir) , "cycles-mode build should carry RC";
        nogc_ir = _compile_ir(`entry, "none", ENFORCE);
        assert not _carries_rc(nogc_ir) , "stale cycles-mode cache leaked into the gc-none build";
    }
}
