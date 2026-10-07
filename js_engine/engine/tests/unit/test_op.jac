import from engine.src.bytecode.op {
    Opcode,
    Instruction,
    make_instruction,
    make_op,
    ConstantPool,
    make_constant_pool,
    CompiledFunction,
    make_compiled_fn,
    opcode_name,
    disassemble,
    opcode_to_int,
    opcode_from_int
}
import from engine.src.ffi.libc { fflush, _exit }

# ══════════════════════════════════════════════════════════════════════════════
# Smoke tests
# ══════════════════════════════════════════════════════════════════════════════

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

with entry {
    # ─── 1. Opcode enum values (stack group) ────────────────────────────────
    _chki("LOAD_CONST=0", opcode_to_int(Opcode.LOAD_CONST), 0);
    _chki("LOAD_UNDEFINED=1", opcode_to_int(Opcode.LOAD_UNDEFINED), 1);
    _chki("LOAD_NULL=2", opcode_to_int(Opcode.LOAD_NULL), 2);
    _chki("LOAD_TRUE=3", opcode_to_int(Opcode.LOAD_TRUE), 3);
    _chki("LOAD_FALSE=4", opcode_to_int(Opcode.LOAD_FALSE), 4);
    _chki("POP=5", opcode_to_int(Opcode.POP), 5);
    _chki("DUP=6", opcode_to_int(Opcode.DUP), 6);
    _chki("SWAP=7", opcode_to_int(Opcode.SWAP), 7);

    # ─── 2. Opcode enum values (variables group) ────────────────────────────
    _chki("LOAD_LOCAL=8", opcode_to_int(Opcode.LOAD_LOCAL), 8);
    _chki("STORE_LOCAL=9", opcode_to_int(Opcode.STORE_LOCAL), 9);
    _chki("LOAD_GLOBAL=10", opcode_to_int(Opcode.LOAD_GLOBAL), 10);
    _chki("STORE_GLOBAL=11", opcode_to_int(Opcode.STORE_GLOBAL), 11);

    # ─── 3. Opcode enum values (arithmetic group) ───────────────────────────
    _chki("ADD=24", opcode_to_int(Opcode.ADD), 24);
    _chki("SUB=25", opcode_to_int(Opcode.SUB), 25);
    _chki("MUL=26", opcode_to_int(Opcode.MUL), 26);
    _chki("DIV=27", opcode_to_int(Opcode.DIV), 27);
    _chki("NEG=30", opcode_to_int(Opcode.NEG), 30);

    # ─── 4. Opcode enum values (comparison group) ───────────────────────────
    _chki("EQ=38", opcode_to_int(Opcode.EQ), 38);
    _chki("STRICT_EQ=44", opcode_to_int(Opcode.STRICT_EQ), 44);
    _chki("STRICT_NEQ=45", opcode_to_int(Opcode.STRICT_NEQ), 45);

    # ─── 5. Opcode enum values (control group) ──────────────────────────────
    _chki("JUMP=52", opcode_to_int(Opcode.JUMP), 52);
    _chki("JUMP_IF_TRUE=53", opcode_to_int(Opcode.JUMP_IF_TRUE), 53);
    _chki("JUMP_IF_FALSE=54", opcode_to_int(Opcode.JUMP_IF_FALSE), 54);

    # ─── 6. Opcode enum values (function group) ─────────────────────────────
    _chki("CALL=57", opcode_to_int(Opcode.CALL), 57);
    _chki("RETURN=60", opcode_to_int(Opcode.RETURN), 60);
    _chki("MAKE_FUNCTION=62", opcode_to_int(Opcode.MAKE_FUNCTION), 62);

    # ─── 7. Opcode enum values (exception group) ────────────────────────────
    _chki("THROW=68", opcode_to_int(Opcode.THROW), 68);
    _chki("PUSH_CATCH=69", opcode_to_int(Opcode.PUSH_CATCH), 69);

    # ─── 8. Opcode enum values (misc group) ─────────────────────────────────
    _chki("NOP=77", opcode_to_int(Opcode.NOP), 77);
    _chki("EXPORT=80", opcode_to_int(Opcode.EXPORT), 80);

    # ─── 9. Instruction construction ────────────────────────────────────────
    ins1: Instruction = make_op(Opcode.POP);
    _chki("make_op opcode", opcode_to_int(ins1.opcode), opcode_to_int(Opcode.POP));
    _chki("make_op arg=0", ins1.arg, 0);
    _chki("make_op arg2=0", ins1.arg2, 0);
    _chki("make_op line=0", ins1.line, 0);

    ins2: Instruction = make_instruction(Opcode.LOAD_CONST, 3, 0, 12);
    _chki("ins opcode", opcode_to_int(ins2.opcode), opcode_to_int(Opcode.LOAD_CONST));
    _chki("ins arg", ins2.arg, 3);
    _chki("ins line", ins2.line, 12);

    ins3: Instruction = make_instruction(Opcode.CALL_METHOD, 2, 7, 5);
    _chki("call_method arg", ins3.arg, 2);
    _chki("call_method arg2", ins3.arg2, 7);

    # ─── 10. ConstantPool add / get round-trip ──────────────────────────────
    pool: ConstantPool = make_constant_pool();
    _chki("empty pool size", pool.size(), 0);
}

glob v0: str = "undefined",
     v1: str = "42",
     v2: str = "true";

with entry {
    idx0: int = pool.add(v0);
    idx1: int = pool.add(v1);
    idx2: int = pool.add(v2);

    _chki("add returns 0", idx0, 0);
    _chki("add returns 1", idx1, 1);
    _chki("add returns 2", idx2, 2);
    _chki("pool size after 3", pool.size(), 3);

    got0: str = pool.get(0);
    got1: str = pool.get(1);
    got2: str = pool.get(2);

    _chk("get(0) is undefined", got0 == "undefined");
    _chk("get(1) is 42", got1 == "42");
    _chk("get(2) is true", got2 == "true");

    # ─── 11. CompiledFunction creation ──────────────────────────────────────
    fn: CompiledFunction = make_compiled_fn("add", "test.js");
    _chks("fn.name", fn.name, "add");
    _chks("fn.file", fn.file, "test.js");
    _chki("fn.num_locals=0", fn.num_locals, 0);
    _chk("fn.is_strict=False", fn.is_strict == False);
    _chk("fn.is_async=False", fn.is_async == False);
    _chk("fn.is_generator=False", fn.is_generator == False);
    _chki("fn.code empty", len(fn.code), 0);
    _chki("fn.constants empty", fn.constants.size(), 0);
    _chki("fn.params empty", len(fn.params), 0);

    # ─── 12. Populating a CompiledFunction ──────────────────────────────────
    fn2: CompiledFunction = make_compiled_fn("factorial", "fact.js");
    fn2.params.append("n");
    fn2.num_locals = 2;
    fn2.code.append(make_instruction(Opcode.LOAD_LOCAL, 0, 0, 1));
    fn2.code.append(make_instruction(Opcode.LOAD_CONST, 0, 0, 1));
    fn2.code.append(make_op(Opcode.LTE));
    fn2.code.append(make_instruction(Opcode.JUMP_IF_FALSE, 6, 0, 1));
    fn2.code.append(make_op(Opcode.LOAD_TRUE));
    fn2.code.append(make_op(Opcode.RETURN));
    fn2.code.append(make_op(Opcode.LOAD_LOCAL));
    fn2.code.append(make_op(Opcode.RETURN));
    fn2.constants.add("1");

    _chki("fn2 param count", len(fn2.params), 1);
    _chks("fn2 param[0]", fn2.params[0], "n");
    _chki("fn2 num_locals=2", fn2.num_locals, 2);
    _chki("fn2 code len", len(fn2.code), 8);
    _chki("fn2 const pool size", fn2.constants.size(), 1);

    # ─── 13. opcode_name helper ──────────────────────────────────────────────
    _chks("opname LOAD_CONST", opcode_name(Opcode.LOAD_CONST), "LOAD_CONST");
    _chks("opname ADD", opcode_name(Opcode.ADD), "ADD");
    _chks("opname RETURN", opcode_name(Opcode.RETURN), "RETURN");
    _chks("opname JUMP_IF_FALSE", opcode_name(Opcode.JUMP_IF_FALSE), "JUMP_IF_FALSE");
    _chks("opname THROW", opcode_name(Opcode.THROW), "THROW");
    _chks("opname NOP", opcode_name(Opcode.NOP), "NOP");
    _chks("opname EXPORT", opcode_name(Opcode.EXPORT), "EXPORT");

    # ─── 14. disassemble output ─────────────────────────────────────────────
    fn3: CompiledFunction = make_compiled_fn("greet", "hello.js");
    fn3.params.append("name");
    fn3.code.append(make_instruction(Opcode.LOAD_LOCAL, 0, 0, 1));
    fn3.code.append(make_op(Opcode.RETURN));

    asm: str = disassemble(fn3);
    _chk("disasm has fn name", "greet" in asm);
    _chk("disasm has LOAD_LOCAL", "LOAD_LOCAL" in asm);
    _chk("disasm has RETURN", "RETURN" in asm);
    _chk("disasm has params", "1 params" in asm);
}

glob
     # ─── Full opcode table: id round-trip + mnemonics ───────────────────────
     # opcode_to_int / opcode_from_int / _opname are hand-written chains that
     # must stay in sync with the Opcode enum (the ids are .jsbc ABI). Walk every
     # id: a missing or mistyped arm in any chain shows up here. OPCODE_COUNT is
     # the enum's size — adding an opcode means bumping it (and JSBC_FORMAT_VER).
     OPCODE_COUNT: int = 146;
with entry {
    rt_bad: int = 0;
    name_bad: int = 0;
}

glob seen_names: dict[str, int] = {};
with entry {
    n: int = 0;
    while n < OPCODE_COUNT {
        op: Opcode = opcode_from_int(n);
        back: int = opcode_to_int(op);
        if back != n {
            rt_bad = rt_bad + 1;
            print("FAIL: opcode id round-trip " + str(n) + " -> " + str(back));
        }
        nm: str = opcode_name(op);
        if nm == "UNKNOWN" or nm in seen_names {
            name_bad = name_bad + 1;
            print(
                "FAIL: opcode " + str(n) + " mnemonic '" + nm + "' unknown or duplicate"
            );
        } else {
            seen_names[nm] = n;
        }
        n = n + 1;
    }
    _chki("opcode ids round-trip 0..OPCODE_COUNT-1", rt_bad, 0);
    _chki("opcode mnemonics known and unique", name_bad, 0);
    # First id past the table must not decode to a real opcode other than the
    # documented NOP fallback.
    _chki(
        "id OPCODE_COUNT falls back to NOP",
        opcode_to_int(opcode_from_int(OPCODE_COUNT)),
        opcode_to_int(Opcode.NOP)
    );
    _chki(
        "id -1 falls back to NOP",
        opcode_to_int(opcode_from_int(-1)),
        opcode_to_int(Opcode.NOP)
    );

    # ─── Summary ────────────────────────────────────────────────────────────
    print("Opcode smoke tests: passed=" + str(_ok) + " failed=" + str(_fail));
    if _fail > 0 {
        fflush(0);
        _exit(1);
    }
}
