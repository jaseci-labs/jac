"""jac-gdb-helper — GDB Python extension for Jac native debug support.

Loaded by `jac-gdb` after transpilation to Python via `jac jac2py`.
Provides GDB commands:

  jac-load-symbols [path]   — Load debug symbols from a .symmap file
  jac-auto-symbols          — Auto-search and load symbols after a crash
  jac-bt                    — Show a Jac-only backtrace

The .symmap file (produced by JAC_NATIVE_DEBUG=1) contains:
  Line 1: path to the debug .o file (ELF with DWARF sections)
  Line 2: hex address of the .text region in JIT memory
  Lines 3+: <function_name> <hex_addr>  (per-function JIT addresses)
"""

import glob;
import os;
import gdb;


class JacLoadSymbols(gdb.Command) {
    """Load Jac native debug symbols from a .symmap file."""

    def __init__(self: JacLoadSymbols) {
        gdb.Command.__init__(self, "jac-load-symbols", gdb.COMMAND_USER);
    }

    def _find_symmap(self: JacLoadSymbols, arg: str) -> str {
        if arg {
            return arg;
        }
        env_path = os.environ.get("JAC_SYMMAP_PATH", "");
        if env_path and os.path.isfile(env_path) {
            return env_path;
        }
        candidates = glob.glob("/tmp/jac_debug*.symmap");
        candidates += glob.glob("**/.jac_ir/*.symmap", recursive=True);
        if candidates {
            candidates.sort(key=lambda p: os.path.getmtime(p), reverse=True);
            return candidates[0];
        }
        return "";
    }

    def invoke(self: JacLoadSymbols, arg: str, _from_tty: bool) {
        symmap_path = self._find_symmap(arg.strip());
        if not symmap_path or not os.path.isfile(symmap_path) {
            gdb.write(
                "Error: no .symmap file found.\n"
                "  Ensure JAC_NATIVE_DEBUG=1 was set during compilation.\n"
                "  Usage: jac-load-symbols /path/to/file.symmap\n"
            );
            return;
        }
        try {
            with open(symmap_path) as f {
                lines = [ln.strip() for ln in f if ln.strip()];
            }
        } except Exception as e {
            gdb.write(f"Error reading {symmap_path}: {e}\n");
            return;
        }
        if len(lines) < 2 {
            gdb.write(f"Error: malformed symmap (need >=2 lines): {symmap_path}\n");
            return;
        }
        obj_path = lines[0];
        text_addr = lines[1];
        # Parse per-function JIT addresses
        fn_jit_addrs: dict[str, int] = {};
        for line in lines[2:] {
            parts = line.split();
            if len(parts) == 2 {
                fn_jit_addrs[parts[0]] = int(parts[1], 16);
            }
        }
        if not os.path.isfile(obj_path) {
            gdb.write(f"Error: debug object not found: {obj_path}\n");
            return;
        }
        # Determine code section name and function offsets
        code_section = ".text";
        fn_obj_offsets: dict[str, int] = {};
        try {
            import subprocess;
            _readelf_s = subprocess.run(
                ["readelf", "-S", obj_path], capture_output=True, text=True
            );
            if ".ltext" in _readelf_s.stdout {
                code_section = ".ltext";
            }
            _readelf_sym = subprocess.run(
                ["readelf", "-s", obj_path], capture_output=True, text=True
            );
            for line in _readelf_sym.stdout.splitlines() {
                parts = line.split();
                if len(parts) >= 8 and parts[3] == "FUNC" {
                    fn_obj_offsets[parts[7]] = int(parts[1], 16);
                }
            }
        } except Exception {}

        # Compute section base: fn_jit_addr - fn_obj_offset
        section_base = int(text_addr, 16);
        for (fname, jit_addr) in fn_jit_addrs.items() {
            if fname in fn_obj_offsets {
                section_base = jit_addr - fn_obj_offsets[fname];
                break;
            }
        }
        section_base_hex = f"0x{section_base:x}";
        gdb.write(f"Loading debug symbols from: {obj_path}\n");
        gdb.write(f"  {code_section} base: {section_base_hex}\n");
        try {
            gdb.execute("set confirm off");
            cmd = f"add-symbol-file {obj_path} -s {code_section} {section_base_hex}";
            gdb.execute(cmd, to_string=False);
            gdb.execute("set confirm on");
        } except Exception as e {
            gdb.write(f"Warning: add-symbol-file failed: {e}\n");
            gdb.execute("set confirm on");
            return;
        }
        if fn_jit_addrs {
            gdb.write("\nJIT function addresses:\n");
            for (fname, jit_addr) in fn_jit_addrs.items() {
                gdb.write(f"  {fname:40s} 0x{jit_addr:x}\n");
            }
        }
        gdb.write("\nSymbols loaded. Use 'jac-bt' for a Jac-only backtrace.\n");
    }
}


class JacAutoSymbols(gdb.Command) {
    """Automatically search for and load Jac debug symbols after a crash."""

    def __init__(self: JacAutoSymbols) {
        gdb.Command.__init__(self, "jac-auto-symbols", gdb.COMMAND_USER);
    }

    def invoke(self: JacAutoSymbols, arg: str, _from_tty: bool) {
        symmap_path = os.environ.get("JAC_SYMMAP_PATH", "");
        if symmap_path and os.path.isfile(symmap_path) {
            gdb.execute(f"jac-load-symbols {symmap_path}");
        } else {
            gdb.execute("jac-load-symbols");
        }
    }
}


class JacBacktrace(gdb.Command) {
    """Show a Jac-only backtrace from jac_entry down to the crash.

    Filters out Python, ctypes, ffi, and libc frames so only the
    native Jac call chain is visible."""

    def __init__(self: JacBacktrace) {
        gdb.Command.__init__(self, "jac-bt", gdb.COMMAND_USER);
    }

    def invoke(self: JacBacktrace, _arg: str, _from_tty: bool) {
        frame = gdb.newest_frame();
        frames: list = [];
        while frame is not None {
            frames.append(frame);
            try {
                frame = frame.older();
            } except Exception {
                break;
            }
        }
        jac_entry_idx: (int | None) = None;
        for (i, f) in enumerate(frames) {
            name = f.name() or "";
            if name == "jac_entry" {
                jac_entry_idx = i;
                break;
            }
        }
        if jac_entry_idx is None {
            gdb.write("jac_entry not found in trace — showing full bt:\n\n");
            gdb.execute("bt");
            return;
        }
        gdb.write("Jac backtrace:\n");
        for i in range(jac_entry_idx + 1) {
            f = frames[i];
            name = f.name() or "??";
            sal = f.find_sal();
            loc = "";
            if sal.symtab {
                loc = f" at {sal.symtab.filename}:{sal.line}";
            }
            gdb.write(f"  #{i:<3d} 0x{f.pc():016x} in {name}(){loc}\n");
        }
        gdb.write("\n");
    }
}


# Register commands when sourced by GDB
with entry {
    JacLoadSymbols();
    JacAutoSymbols();
    JacBacktrace();
    gdb.write("[jac-gdb] Helper loaded. Commands: jac-bt, jac-load-symbols, jac-auto-symbols\n");
}
