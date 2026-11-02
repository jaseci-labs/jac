"""Build-time bytecode compiler for the engine's JavaScript builtins.

    js_compiler <builtins/js dir> <builtins.jsbc> <module.js>...   compile the builtins into the pack
    js_compiler --disasm <file.js>                                 print its stack and register bytecode

`zig build` runs the first form over every .js under the builtins directory
(paths relative to it) and ships the pack beside libjs_engine.so,
which loads builtins from it instead of parsing their source. A module's key
in the pack is its path under builtins/js/ without ".js" ("fs/promises"), and
each is compiled exactly as the runtime's _cjs_run_in_module would: hash the
raw source, wrap it as CommonJS, parse, compile, encode.

Only the parser and compiler run here (no event loop, no global object), so
sources are read with plain `open().read()`, and the pack is written with
libc fwrite of exact byte counts (a Jac str stops at the first NUL).
"""

import sys;
import from engine.src.parser.parser { parse }
import from engine.src.bytecode.compiler { make_compiler }
import from engine.src.bytecode.op { CompiledFunction, disassemble }
import from engine.src.bytecode.regisa { reg_disassemble, reg_translate_fn }
import from engine.src.bytecode.jsbc {
    jsbc_encode,
    jsbc_pack_header,
    _cjs_wrap_source,
    JSBCBlob
}
import from engine.src.runtime.jsstring { str_hash }
import from engine.src.ffi.libc { fflush, _exit, stack_expand, fopen, fwrite, fclose }

import from engine.src.runtime.mem {
    str_bslice,
    str_nbytes
}

"""Compile one builtin's source to its bytecode blob."""
def compile_builtin(path: str) -> JSBCBlob {
    raw: str = open(path).read();
    wrapped: str = _cjs_wrap_source(raw);
    c = make_compiler();
    c.source_file = path;
    c.source_text = wrapped;
    top: CompiledFunction = c.compile_program(parse(wrapped, False, False));
    return jsbc_encode(top, c.all_fns, str_hash(raw));
}

"""Compile the builtins `modules` (paths under `base`) into the pack at `out_path`."""
def build_pack(base: str, out_path: str, modules: list[str]) -> int {
    keys: list[str] = [];
    blobs: list[JSBCBlob] = [];
    for rel in sorted(modules) {
        keys.append(str_bslice(rel, 0, str_nbytes(rel) - 3));
        blobs.append(compile_builtin(base + "/" + rel));
    }
    hdr: JSBCBlob = jsbc_pack_header(keys, [b.size for b in blobs]);
    f: int = fopen(out_path, "wb");
    if f == 0 {
        print("js_compiler: cannot write " + out_path);
        return 1;
    }
    ok: bool = fwrite(hdr.ptr, 1, hdr.size, f) == hdr.size;
    for b in blobs {
        ok = ok and fwrite(b.ptr, 1, b.size, f) == b.size;
    }
    fclose(f);
    if not ok {
        print("js_compiler: short write " + out_path);
        return 1;
    }
    return 0;
}

"""Print the stack and register disassembly of every function in `path`."""
def disasm(path: str) -> int {
    wrapped: str = _cjs_wrap_source(open(path).read());
    c = make_compiler();
    c.source_file = path;
    c.source_text = wrapped;
    fns: list[CompiledFunction] = [c.compile_program(parse(wrapped, False, False))];
    fns.extend(c.all_fns);
    for fn in fns {
        reg_translate_fn(fn);
        print(disassemble(fn));
        print(reg_disassemble(fn));
    }
    return 0;
}

with entry {
    # Large builtins (stream.js, crypto.js) recurse deeply in the parser and
    # compiler, as the engine's own entry allows for.
    stack_expand();
    exit_code: int = 2;
    if len(sys.argv) == 3 and sys.argv[1] == "--disasm" {
        exit_code = disasm(sys.argv[2]);
    } elif len(sys.argv) > 3 {
        exit_code = build_pack(sys.argv[1], sys.argv[2], sys.argv[3:]);
    } else {
        print("usage: js_compiler <builtins/js dir> <builtins.jsbc> <module.js>...");
        print("       js_compiler --disasm <file.js>");
    }
    fflush(0);
    _exit(exit_code);
}
