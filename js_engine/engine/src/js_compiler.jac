"""
js_engine/engine/src/js_compiler.na.jac — developer/build-time bytecode compiler.

Compiles ONE CommonJS builtin `*.js` to a `*.jsbc` precompiled-bytecode file
(see docs/jsbc_bytecode_cache_plan.md). This is a thin entry point that reuses
the exact same parse → compile pipeline as the runtime, but does NOT start the
event loop or bootstrap the JS global object — it only needs the parser +
compiler (verified import-clean in Phase 0.2).

Usage:
    js_compiler <in.js> <out.jsbc>

The Makefile `builtins-bytecode` target shell-loops this over every
engine/src/builtins/js/*.js to (re)generate the sibling .jsbc files, which are
committed and shipped. The engine never compiles builtin JS at runtime.

Source IO uses PLAIN native `open().read()` (the same primitive main.na.jac reads
its input with) — NOT the libuv/JSValue-based `_read_file_sync_str` (that needs
the runtime string-intern table + realm, which this standalone tool never
bootstraps; it aborts otherwise — verified Phase 2).

The `.jsbc` output is a PACKED BINARY blob (v4) and is written with libc
`fwrite` of exactly `blob.size` raw bytes — `open(out,"w").write(str)` is NOT
binary-safe (a Jac str truncates at the first embedded NUL).

Steps (must match _cjs_run_in_module in vm.na.jac exactly):
    1. read RAW source
    2. source_hash = str_hash(raw)                 (deterministic — Phase 0.1)
    3. wrapped = _cjs_wrap_source(raw)             (SHARED wrapper)
    4. ast = parse(wrapped, False, False)
    5. c = make_compiler(); c.source_file = <in>; c.source_text = wrapped;
       top = c.compile_program(ast)
    6. blob = jsbc_encode(top, c.all_fns, source_hash)  -> JSBCBlob{ptr,size}
    7. fwrite blob.size raw bytes to <out.jsbc>
"""

import from engine.src.parser.parser { parse }
import from engine.src.bytecode.compiler { make_compiler }
import from engine.src.bytecode.op { CompiledFunction, disassemble }
import from engine.src.bytecode.regisa {
    reg_disassemble,
    reg_isa_debug_set,
    reg_translate_fn
}
import from engine.src.bytecode.jsbc { jsbc_encode, _cjs_wrap_source, JSBCBlob }
import from engine.src.runtime.jsstring { str_hash }
import from engine.src.ffi.libc { fflush, _exit, stack_expand, fopen, fwrite, fclose }
import sys;

"""Compile one .js file to .jsbc. Returns 0 on success, non-zero on error."""
def compile_one(in_path: str, out_path: str) -> int {
    raw: str = "";
    try {
        raw = open(in_path).read();
    } except Exception {
        print("js_compiler: cannot read " + in_path);
        return 1;
    }

    source_hash: int = str_hash(raw);
    wrapped: str = _cjs_wrap_source(raw);
    ast = parse(wrapped, False, False);
    c = make_compiler();
    c.source_file = in_path;
    c.source_text = wrapped;
    top: CompiledFunction = c.compile_program(ast);

    # Developer mode: `js_compiler <in.js> -` prints the stack and register
    # disassembly of every function instead of writing a .jsbc (a quick check
    # of the register translator without building the engine).
    if out_path == "-" {
        reg_translate_fn(top);
        print(disassemble(top));
        print(reg_disassemble(top));
        dfi: int = 0;
        while dfi < len(c.all_fns) {
            reg_translate_fn(c.all_fns[dfi]);
            print(disassemble(c.all_fns[dfi]));
            print(reg_disassemble(c.all_fns[dfi]));
            dfi = dfi + 1;
        }
        return 0;
    }

    blob: JSBCBlob = jsbc_encode(top, c.all_fns, source_hash);
    # Write the packed-binary blob with libc fwrite (binary-safe, exact length).
    # open(out,"w").write(str) truncates at the first NUL — never use it here.
    f: int = fopen(out_path, "wb");
    if f == 0 {
        print("js_compiler: cannot write " + out_path);
        return 1;
    }
    written: int = fwrite(blob.ptr, 1, blob.size, f);
    fclose(f);
    # No io_free(blob.ptr): io_alloc is calloc (Boehm-GC backed) — libc free on it
    # crashes. The buffer is left for GC; the process _exit()s right after anyway.
    if written != blob.size {
        print(
            "js_compiler: short write "
                + out_path
                + " ("
                + str(written)
                + "/"
                + str(blob.size)
                + " bytes)"
        );
        return 1;
    }
    print(
        "js_compiler: "
            + in_path
            + " -> "
            + out_path
            + " ("
            + str(1 + len(c.all_fns))
            + " fns, "
            + str(blob.size)
            + " bytes)"
    );
    return 0;
}

with entry {
    # Compiling large builtins (stream.js, crypto.js) recurses deeply in the
    # parser/compiler — expand the stack like main.na.jac does.
    stack_expand();
    exit_code: int = 0;
    if len(sys.argv) < 3 {
        print("usage: js_compiler <in.js> <out.jsbc>");
        exit_code = 2;
    } else {
        in_path: str = sys.argv[1];
        out_path: str = sys.argv[2];
        if out_path == "-" {
            reg_isa_debug_set(True);
        }
        exit_code = compile_one(in_path, out_path);
        if exit_code != 0 {
            print("js_compiler: FAILED (" + str(exit_code) + ")");
        }
    }
    # Flush stdio then exit with a real code so the Makefile loop fails loudly.
    fflush(0);
    _exit(exit_code);
}
