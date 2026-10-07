"""
Round-trip unit test for the .jsbc serializer/deserializer (Phase 1).

Two levels of coverage:
  A. Synthetic CompiledFunction tree built by hand — exercises every serialized
     field (all flags, all list kinds, all const type-tags n:/b:/s:/regex/bare,
     multi-instruction code with arg/arg2/line/arg3, nested fns) and asserts the
     decoded tree is field-for-field identical to the original.
  B. A real compiler run over a representative snippet (nested fns, closure,
     generator, strict, numeric/bigint/regex/string consts) → encode → decode →
     assert every CompiledFunction, Instruction, and constant is byte-identical.

Run: jac run engine/tests/unit/test_jsbc.na.jac   (expects failed=0)
"""

import from engine.src.bytecode.op {
    Opcode,
    Instruction,
    make_instruction,
    ConstantPool,
    make_constant_pool,
    CompiledFunction,
    make_compiled_fn,
    opcode_name
}
import from engine.src.bytecode.jsbc {
    jsbc_encode,
    jsbc_decode,
    JSBCModule,
    JSBCBlob,
    _cjs_wrap_source,
    JSBC_FORMAT_VER,
    JSBC_OPCODE_COUNT
}
import from engine.src.runtime.mem { io_alloc, read_byte, write_byte }
import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.parser.parser { parse }
import from engine.src.bytecode.compiler { make_compiler }

glob _ok: int = 0,
     _fail: int = 0;

def _chk(label: str, got: bool) {
    if got {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + label);
    }
}

def _chki(label: str, got: int, want: int) {
    if got == want {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + label + " — got " + str(got) + " want " + str(want));
    }
}

def _chks(label: str, got: str, want: str) {
    if got == want {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + label + " — got '" + got + "' want '" + want + "'");
    }
}

# Assert two CompiledFunctions are field-for-field identical.
def _cmp_fn(label: str, a: CompiledFunction, b: CompiledFunction) {
    _chks(label + ".name", b.name, a.name);
    _chks(label + ".file", b.file, a.file);
    _chki(label + ".num_locals", b.num_locals, a.num_locals);
    _chki(label + ".param_base", b.param_base, a.param_base);
    _chki(label + ".arguments_slot", b.arguments_slot, a.arguments_slot);
    _chki(label + ".expected_arg_count", b.expected_arg_count, a.expected_arg_count);
    _chki(label + ".gen_prologue_end_ip", b.gen_prologue_end_ip, a.gen_prologue_end_ip);
    _chk(label + ".is_strict", b.is_strict == a.is_strict);
    _chk(label + ".is_async", b.is_async == a.is_async);
    _chk(label + ".is_generator", b.is_generator == a.is_generator);
    _chk(label + ".is_method", b.is_method == a.is_method);
    _chk(label + ".has_rest", b.has_rest == a.has_rest);
    _chk(label + ".is_bound", b.is_bound == a.is_bound);
    _chk(label + ".is_field_init", b.is_field_init == a.is_field_init);
    # list[str] fields
    _chki(label + ".locals.len", len(b.locals), len(a.locals));
    li: int = 0;
    while li < len(a.locals) and li < len(b.locals) {
        _chks(label + ".locals[" + str(li) + "]", b.locals[li], a.locals[li]);
        li = li + 1;
    }
    _chki(label + ".params.len", len(b.params), len(a.params));
    pi: int = 0;
    while pi < len(a.params) and pi < len(b.params) {
        _chks(label + ".params[" + str(pi) + "]", b.params[pi], a.params[pi]);
        pi = pi + 1;
    }
    _chki(label + ".free_vars.len", len(b.free_vars), len(a.free_vars));
    fi: int = 0;
    while fi < len(a.free_vars) and fi < len(b.free_vars) {
        _chks(label + ".free_vars[" + str(fi) + "]", b.free_vars[fi], a.free_vars[fi]);
        fi = fi + 1;
    }
    _chki(label + ".free_var_slots.len", len(b.free_var_slots), len(a.free_var_slots));
    si: int = 0;
    while si < len(a.free_var_slots) and si < len(b.free_var_slots) {
        _chki(
            label + ".free_var_slots[" + str(si) + "]",
            b.free_var_slots[si],
            a.free_var_slots[si]
        );
        si = si + 1;
    }
    _chki(label + ".lexical_names.len", len(b.lexical_names), len(a.lexical_names));
    xi: int = 0;
    while xi < len(a.lexical_names) and xi < len(b.lexical_names) {
        _chks(
            label + ".lexical_names[" + str(xi) + "]",
            b.lexical_names[xi],
            a.lexical_names[xi]
        );
        xi = xi + 1;
    }
    # constants
    _chki(label + ".constants.len", len(b.constants.values), len(a.constants.values));
    ci: int = 0;
    while ci < len(a.constants.values) and ci < len(b.constants.values) {
        _chks(
            label + ".constants[" + str(ci) + "]",
            b.constants.values[ci],
            a.constants.values[ci]
        );
        ci = ci + 1;
    }
    # code
    _chki(label + ".code.len", len(b.code), len(a.code));
    ki: int = 0;
    while ki < len(a.code) and ki < len(b.code) {
        ai: Instruction = a.code[ki];
        bi: Instruction = b.code[ki];
        _chks(
            label + ".code[" + str(ki) + "].op",
            opcode_name(bi.opcode),
            opcode_name(ai.opcode)
        );
        _chki(label + ".code[" + str(ki) + "].arg", bi.arg, ai.arg);
        _chki(label + ".code[" + str(ki) + "].arg2", bi.arg2, ai.arg2);
        _chki(label + ".code[" + str(ki) + "].line", bi.line, ai.line);
        _chki(label + ".code[" + str(ki) + "].arg3", bi.arg3, ai.arg3);
        ki = ki + 1;
    }
}

with entry {
    # ══════════════════════════════════════════════════════════════════════
    # A. Synthetic tree — exhaustive field coverage
    # ══════════════════════════════════════════════════════════════════════

    # top_fn: strict + async + generator, with every list populated, all const
    # type-tags, and a code stream using arg/arg2/line/arg3.
    top: CompiledFunction = make_compiled_fn("<main>", "synthetic.js");
    top.num_locals = 7;
    top.param_base = 2;
    top.arguments_slot = 3;
    top.expected_arg_count = 2;
    top.gen_prologue_end_ip = 5;
    top.is_strict = True;
    top.is_async = True;
    top.is_generator = True;
    top.is_method = False;
    top.has_rest = True;
    top.is_bound = False;
    top.is_field_init = True;
    top.locals.append("a");
    top.locals.append("b");
    top.locals.append("");  # empty string element (edge case)
    top.params.append("x");
    top.params.append("y");
    top.free_vars.append("outer");
    top.free_vars.append("captured");
    top.free_var_slots.append(4);
    top.free_var_slots.append(-1);  # transitive capture sentinel
    top.lexical_names.append("let1");
    top.lexical_names.append("const2");
    # constants: numeric, bigint, string (with newline!), regex, bare ident
    top.constants.values.append("n:42");
    top.constants.values.append("n:0x1F");
    top.constants.values.append("b:12345678901234567890");
    top.constants.values.append("s:hello world");
    top.constants.values.append("s:line1\nline2\nline3");  # embedded newlines
    top.constants.values.append("s:");  # empty string const
    top.constants.values.append("globalThis");  # bare identifier
    top.code.append(make_instruction(Opcode.LOAD_CONST, 0, 0, 1, 0));
    top.code.append(make_instruction(Opcode.GET_PROP, 6, 3, 2, 1));
    top.code.append(make_instruction(Opcode.MAKE_FUNCTION, 1, 0, 3, 0));
    top.code.append(make_instruction(Opcode.CALL, 2, 0, 4, 0));
    top.code.append(make_instruction(Opcode.RETURN, 0, 0, 5, 0));

    # A nested fn with mostly-default/empty fields (min coverage)
    nested: CompiledFunction = make_compiled_fn("inner", "synthetic.js");
    nested.num_locals = 1;
    nested.is_method = True;
    nested.constants.values.append("n:3.14");
    nested.code.append(make_instruction(Opcode.LOAD_LOCAL, 0, 0, 10, 0));
    nested.code.append(make_instruction(Opcode.RETURN, 0, 0, 10, 0));

    all_fns: list[CompiledFunction] = [nested];

    # The encoding is a packed binary blob (varints, raw bytes, embedded NULs),
    # so it is inspected through raw byte reads, never through a Jac str.
    blob: JSBCBlob = jsbc_encode(top, all_fns, 1653687373046440190);
    _chk("encode non-empty", blob.ptr != 0 and blob.size > 4);
    _chk(
        "encode starts with JSBC magic",
        read_byte(blob.ptr, 0) == 74
            and read_byte(blob.ptr, 1) == 83
            and read_byte(blob.ptr, 2) == 66
            and read_byte(blob.ptr, 3) == 67
    );

    mod: JSBCModule = jsbc_decode(blob.ptr, blob.size);
    _chk("decode ok", mod.ok);
    _chks("decode err empty", mod.err, "");
    _chki("decode format_ver", mod.format_ver, JSBC_FORMAT_VER);
    _chki("decode opcode_count", mod.opcode_count, JSBC_OPCODE_COUNT);
    _chki("decode source_hash", mod.source_hash, 1653687373046440190);
    _chki("decode fn_count", 1 + len(mod.all_fns), 2);

    _cmp_fn("A.top", top, mod.top_fn);
    if len(mod.all_fns) >= 1 {
        _cmp_fn("A.nested", nested, mod.all_fns[0]);
    }
}

glob
     # ══════════════════════════════════════════════════════════════════════
     # B. Real compiler run → round-trip
     # ══════════════════════════════════════════════════════════════════════

     raw: str = (
         "'use strict';\n"
         + "const bignum = 900719925474099267890n;\n"
         + "const re = /ab+c/gi;\n"
         + "function outer(z){ return function(){ return z * 2; }; }\n"
         + "function* gen(){ yield 1; yield 'two'; }\n"
         + "module.exports = { outer: outer, gen: gen, bignum: bignum, re: re };\n"
     );

with entry {
    wrapped: str = _cjs_wrap_source(raw);
    ast = parse(wrapped, False, False);
    c = make_compiler();
    c.source_file = "roundtrip.js";
    real_top: CompiledFunction = c.compile_program(ast);
    real_fns: list[CompiledFunction] = c.all_fns;

    _chks("B.top name is <main>", real_top.name, "<main>");
    _chk("B.has nested fns", len(real_fns) > 0);

    blob2: JSBCBlob = jsbc_encode(real_top, real_fns, 42);
    mod2: JSBCModule = jsbc_decode(blob2.ptr, blob2.size);
    _chk("B.decode ok", mod2.ok);
    _chki("B.fn_count preserved", 1 + len(mod2.all_fns), 1 + len(real_fns));

    _cmp_fn("B.top", real_top, mod2.top_fn);
    bi2: int = 0;
    while bi2 < len(real_fns) and bi2 < len(mod2.all_fns) {
        _cmp_fn("B.fn[" + str(bi2) + "]", real_fns[bi2], mod2.all_fns[bi2]);
        bi2 = bi2 + 1;
    }

    # ══════════════════════════════════════════════════════════════════════
    # C. Failure policy — bad magic → ok=False, no crash
    # ══════════════════════════════════════════════════════════════════════
    bad_buf: int = io_alloc(16);
    write_byte(bad_buf, 0, 78);  # 'N'
    write_byte(bad_buf, 1, 79);  # 'O'
    write_byte(bad_buf, 2, 80);  # 'P'
    write_byte(bad_buf, 3, 69);  # 'E'
    bad: JSBCModule = jsbc_decode(bad_buf, 16);
    _chk("C.bad magic → not ok", bad.ok == False);
    _chk("C.bad magic err set", len(bad.err) > 0);

    # Header from a different format version must be rejected before any
    # function body is decoded (field layout is version-specific).
    stale_buf: int = io_alloc(blob.size);
    si: int = 0;
    while si < blob.size {
        write_byte(stale_buf, si, read_byte(blob.ptr, si));
        si = si + 1;
    }
    # byte 4 is the zigzag varint of format_ver; +2 bumps the value by one.
    write_byte(stale_buf, 4, read_byte(stale_buf, 4) + 2);
    stale: JSBCModule = jsbc_decode(stale_buf, blob.size);
    _chk("C.stale format_ver → not ok", stale.ok == False);

    # Every strict prefix of a valid blob is a truncated file: the bounds-checked
    # reader must report ok=False and never read past the end.
    trunc_accepted: int = 0;
    cut: int = 0;
    while cut < blob.size {
        tm: JSBCModule = jsbc_decode(blob.ptr, cut);
        if tm.ok {
            trunc_accepted = trunc_accepted + 1;
            print(
                "FAIL: truncated blob accepted at length "
                    + str(cut)
                    + " of "
                    + str(blob.size)
            );
        }
        cut = cut + 1;
    }
    _chki("C.every truncation rejected", trunc_accepted, 0);

    # ─── Summary ──────────────────────────────────────────────────────────
    print("JSBC round-trip tests: passed=" + str(_ok) + " failed=" + str(_fail));
    if _fail == 0 {
        print("OK");
    } else {
        fflush(0);
        _exit(1);
    }
}
