"""Standalone WebAssembly spec-suite driver for the Jac-native interpreter.

Runs the .cmds files produced by engine/tests/wasm/spec_cmds.py directly
against engine/src/wasm (no JS engine involved), so the interpreter core can
be built and tested on its own:

    jac build --native engine/tests/wasm/spec_driver.jac -o /tmp/spec_driver
    /tmp/spec_driver <suite.cmds>...

Prints one summary line per suite and the first failures.
"""

import sys;
import from engine.src.ffi.libc { fopen, fread, fclose, calloc, free, fflush, _exit }
import from engine.src.runtime.mem { io_alloc, io_free, str_from_raw }
import from engine.src.wasm.compile {
    WModule,
    WImport,
    compile_module,
    wasm_compile_error,
    f32_bits_to_f64,
    f64_to_f32_bits,
    FuncType,
    T_I32,
    T_I64,
    T_F32,
    T_F64,
    T_FUNCREF,
    EXT_FUNC,
    EXT_TABLE,
    EXT_MEMORY,
    EXT_GLOBAL
}
import from engine.src.wasm.exec {
    WInstance,
    instantiate,
    invoke,
    invoke_result,
    invoke_result_count,
    wasm_trap_message,
    wasm_link_error,
    new_host_func,
    new_memory,
    new_table,
    new_global,
    canon_type,
    set_host_handler,
    export_index,
    global_get
}

glob M32: int = 4294967295,
     _REG_KIND: dict[str, int] = {},
     _REG_VAL: dict[str, int] = {},
     _NAMED: dict[str, WInstance] = {},
     _CUR: WInstance | None = None,
     _HAVE_CUR: bool = False;

# ── Registry: "<module>\x01<field>" -> kind / value ──────────────────────────
def _host(idx: int, slots: int, f: int) -> int {
    return 0;
}

def _reg(mod: str, field: str, kind: int, val: int) {
    _REG_KIND[mod + "\x01" + field] = kind;
    _REG_VAL[mod + "\x01" + field] = val;
}

def _ft(params: list[int], results: list[int]) -> int {
    return canon_type(FuncType(params=params, results=results));
}

def _setup_spectest {
    set_host_handler(_host);
    _reg("spectest", "print", EXT_FUNC, new_host_func(_ft([], []), 0));
    _reg("spectest", "print_i32", EXT_FUNC, new_host_func(_ft([T_I32], []), 0));
    _reg("spectest", "print_i64", EXT_FUNC, new_host_func(_ft([T_I64], []), 0));
    _reg("spectest", "print_f32", EXT_FUNC, new_host_func(_ft([T_F32], []), 0));
    _reg("spectest", "print_f64", EXT_FUNC, new_host_func(_ft([T_F64], []), 0));
    _reg(
        "spectest", "print_i32_f32", EXT_FUNC, new_host_func(_ft([T_I32, T_F32], []), 0)
    );
    _reg(
        "spectest", "print_f64_f64", EXT_FUNC, new_host_func(_ft([T_F64, T_F64], []), 0)
    );
    _reg("spectest", "global_i32", EXT_GLOBAL, new_global(T_I32, False, 666));
    _reg("spectest", "global_i64", EXT_GLOBAL, new_global(T_I64, False, 666));
    _reg(
        "spectest",
        "global_f32",
        EXT_GLOBAL,
        new_global(T_F32, False, __float_bits(float(f32(666.6))))
    );
    _reg(
        "spectest",
        "global_f64",
        EXT_GLOBAL,
        new_global(T_F64, False, __float_bits(666.6))
    );
    _reg("spectest", "table", EXT_TABLE, new_table(T_FUNCREF, 10, 20));
    _reg("spectest", "memory", EXT_MEMORY, new_memory(1, 2));
}

def _register_instance(as_name: str, inst: WInstance) {
    i: int = 0;
    while i < len(inst.export_names) {
        _reg(as_name, inst.export_names[i], inst.export_kinds[i], inst.export_vals[i]);
        i = i + 1;
    }
}

# ── Helpers ──────────────────────────────────────────────────────────────────

glob _FILE_PTR: int = 0,
     _FILE_LEN: int = 0,
     _READ_FAILED: bool = False;

def _read_file(path: str) -> bool {
    fh: int = fopen(path, "rb");
    if fh == 0 {
        return False;
    }
    cap: int = 1 << 20;
    buf: int = calloc(1, cap + 1);
    n: int = 0;
    while True {
        got: int = fread(buf + n, 1, cap - n, fh);
        n = n + got;
        if n < cap {
            break;
        }
        nb: int = calloc(1, cap * 2 + 1);
        k: int = 0;
        while k < n {
            __mem_store_i8(nb + k, __mem_load_i8(buf + k));
            k = k + 1;
        }
        free(buf);
        buf = nb;
        cap = cap * 2;
    }
    fclose(fh);
    _FILE_PTR = buf;
    _FILE_LEN = n;
    return True;
}

def _read_text(path: str) -> str {
    _READ_FAILED = False;
    if not _read_file(path) {
        _READ_FAILED = True;
        return "";
    }
    p: int = io_alloc(_FILE_LEN + 1);
    k: int = 0;
    while k < _FILE_LEN {
        __mem_store_i8(p + k, __mem_load_i8(_FILE_PTR + k));
        k = k + 1;
    }
    free(_FILE_PTR);
    s: str = str_from_raw(p);
    io_free(p);
    return s;
}

def _hexval(c: str) -> int {
    o: int = ord(c);
    if o >= 48 and o <= 57 {
        return o - 48;
    }
    return o - 87;
}

"""Hex-encoded UTF-8 -> str ("-" is the empty name)."""
def _unhex(h: str) -> str {
    if h == "-" {
        return "";
    }
    bs: list[int] = [];
    i: int = 0;
    while i + 1 < len(h) {
        bs.append(_hexval(h[i]) * 16 + _hexval(h[i + 1]));
        i = i + 2;
    }
    out: str = "";
    j: int = 0;
    while j < len(bs) {
        b0: int = bs[j];
        cp: int = b0;
        extra: int = 0;
        if b0 >= 240 {
            cp = b0 & 7;
            extra = 3;
        } elif b0 >= 224 {
            cp = b0 & 15;
            extra = 2;
        } elif b0 >= 192 {
            cp = b0 & 31;
            extra = 1;
        }
        k: int = 1;
        while k <= extra and j + k < len(bs) {
            cp = (cp << 6) | (bs[j + k] & 63);
            k = k + 1;
        }
        if cp == 0 {
            out = out + "\\x00";
        } else {
            out = out + chr(cp);
        }
        j = j + 1 + extra;
    }
    return out;
}

"""Unsigned decimal -> int, wrapping mod 2^64."""
def _udec(s: str) -> int {
    acc: int = 0;
    i: int = 0;
    while i < len(s) {
        acc = wrapping_add(wrapping_mul(acc, 10), ord(s[i]) - 48);
        i = i + 1;
    }
    return acc;
}

"""Parse an argument token into the slot representation."""
def _arg(tok: str) -> int {
    c: int = tok.find(":");
    t: str = tok[:c];
    v: str = tok[c + 1:];
    if t == "i32" {
        return int(i32.wrap(_udec(v)));
    }
    if t == "i64" {
        return _udec(v);
    }
    if t == "f32" {
        return __float_bits(f32_bits_to_f64(_udec(v)));
    }
    if t == "f64" {
        return _udec(v);
    }
    if v == "null" {
        return 0;
    }
    return _udec(v) + 1;  # externref n -> id n+1
}

def _check(tok: str, got: int) -> bool {
    c: int = tok.find(":");
    t: str = tok[:c];
    v: str = tok[c + 1:];
    if t == "i32" {
        return (got & M32) == (_udec(v) & M32);
    }
    if t == "i64" {
        return got == _udec(v);
    }
    if t == "f32" {
        bits: int = f64_to_f32_bits(__bits_float(got));
        if v == "nan:canonical" {
            return (bits & 2147483647) == 2143289344;
        }
        if v == "nan:arithmetic" {
            return (bits & 2143289344) == 2143289344;
        }
        return bits == _udec(v);
    }
    if t == "f64" {
        if v == "nan:canonical" {
            return (got & 9223372036854775807) == 9221120237041090560;
        }
        if v == "nan:arithmetic" {
            return (got & 9221120237041090560) == 9221120237041090560;
        }
        return got == _udec(v);
    }
    if v == "null" {
        return got == 0;
    }
    if t == "externref" {
        return got == _udec(v) + 1;
    }
    return got != 0;
}

# ── Commands ─────────────────────────────────────────────────────────────────

glob _CHECKS: int = 0,
     _FAILS: int = 0,
     _SUITE: str = "";

def _fail(line: str, msg: str) {
    _FAILS = _FAILS + 1;
    if _FAILS <= 12 {
        print("FAIL [" + _SUITE + "] L" + line + " " + msg);
    }
}

def _load_module(path: str) -> WModule | None {
    if not _read_file(path) {
        return None;
    }
    m: WModule | None = compile_module(_FILE_PTR, _FILE_LEN);
    free(_FILE_PTR);
    return m;
}

"""Resolve imports from the registry; returns None-equivalent [] + sets ok."""
glob _LINK_OK: bool = True;

def _resolve(m: WModule) -> list[int] {
    out: list[int] = [];
    _LINK_OK = True;
    for imp in m.imports {
        key: str = imp.module + "\x01" + imp.name;
        if not (key in _REG_KIND) or _REG_KIND[key] != imp.kind {
            _LINK_OK = False;
            out.append(0);
        } else {
            out.append(_REG_VAL[key]);
        }
    }
    return out;
}

def _target(name: str) -> WInstance | None {
    if name == "-" {
        if _HAVE_CUR {
            return _CUR;
        }
        return None;
    }
    if name in _NAMED {
        return _NAMED[name];
    }
    return None;
}

"""Invoke; returns -1 (no such export), 0 ok, 1 trap."""
def _do_invoke(toks: list[str], at: int) -> int {
    inst: WInstance | None = _target(toks[at]);
    if inst == None {
        return -1;
    }
    field: str = _unhex(toks[at + 1]);
    ei: int = export_index(inst, field);
    if ei < 0 {
        return -1;
    }
    nargs: int = int(toks[at + 2]);
    args: list[int] = [];
    k: int = 0;
    while k < nargs {
        args.append(_arg(toks[at + 3 + k]));
        k = k + 1;
    }
    return invoke(inst.export_vals[ei], args);
}

def _run_line(line: str) -> None {
    toks: list[str] = line.split(" ");
    if len(toks) < 2 {
        return;
    }
    cmd: str = toks[0];
    ln: str = toks[1];
    if cmd == "module" {
        m: WModule | None = _load_module(toks[3]);
        if m == None {
            _fail(ln, "module compile: " + wasm_compile_error());
            _HAVE_CUR = False;
            return;
        }
        imps: list[int] = _resolve(m);
        if not _LINK_OK {
            _fail(ln, "module link: unknown import");
            _HAVE_CUR = False;
            return;
        }
        inst: WInstance | None = instantiate(m, imps);
        if inst == None {
            _fail(ln, "module instantiate: " + wasm_link_error() + wasm_trap_message());
            _HAVE_CUR = False;
            return;
        }
        _CUR = inst;
        _HAVE_CUR = True;
        if toks[2] != "-" {
            _NAMED[toks[2]] = inst;
        }
        return;
    }
    if cmd == "register" {
        inst2: WInstance | None = _target(toks[3]);
        if inst2 == None {
            _fail(ln, "register: no module");
            return;
        }
        _register_instance(_unhex(toks[2]), inst2);
        return;
    }
    _CHECKS = _CHECKS + 1;
    if cmd == "assert_return" or cmd == "action" {
        rc: int = _do_invoke(toks, 2);
        if rc < 0 {
            _fail(ln, cmd + ": no such export " + _unhex(toks[3]));
            return;
        }
        if rc != 0 {
            _fail(ln, cmd + ": trapped: " + wasm_trap_message());
            return;
        }
        if cmd == "action" {
            return;
        }
        nargs: int = int(toks[4]);
        ep: int = 5 + nargs;
        nexp: int = int(toks[ep]);
        if invoke_result_count() != nexp {
            _fail(ln, "result count " + str(invoke_result_count()));
            return;
        }
        k: int = 0;
        while k < nexp {
            if not _check(toks[ep + 1 + k], invoke_result(k)) {
                _fail(
                    ln,
                    _unhex(toks[3])
                        + " result "
                        + str(k)
                        + ": want "
                        + toks[ep + 1 + k]
                        + " got "
                        + str(invoke_result(k))
                );
                return;
            }
            k = k + 1;
        }
        return;
    }
    if cmd == "assert_get" {
        inst3: WInstance | None = _target(toks[2]);
        if inst3 == None {
            _fail(ln, "get: no module");
            return;
        }
        ei: int = export_index(inst3, _unhex(toks[3]));
        if ei < 0 {
            _fail(ln, "get: no export");
            return;
        }
        if toks[4] == "-1" {
            return;
        }
        if not _check(toks[5], global_get(inst3.export_vals[ei])) {
            _fail(ln, "get: wrong value");
        }
        return;
    }
    if cmd == "assert_trap" or cmd == "assert_exhaustion" {
        rc2: int = _do_invoke(toks, 2);
        if rc2 != 1 {
            _fail(ln, cmd + ": expected trap, got rc " + str(rc2));
        }
        return;
    }
    if cmd == "assert_invalid" or cmd == "assert_malformed" {
        m2: WModule | None = _load_module(toks[2]);
        if m2 != None {
            _fail(ln, cmd + ": module accepted");
        }
        return;
    }
    if cmd == "assert_unlinkable"
        or cmd == "assert_uninstantiable"
        or cmd == "assert_trap_module" {
        m3: WModule | None = _load_module(toks[2]);
        if m3 == None {
            _fail(ln, cmd + ": compile failed: " + wasm_compile_error());
            return;
        }
        imps2: list[int] = _resolve(m3);
        if not _LINK_OK {
            if cmd != "assert_unlinkable" {
                _fail(ln, cmd + ": unlinkable");
            }
            return;
        }
        inst4: WInstance | None = instantiate(m3, imps2);
        if inst4 != None {
            _fail(ln, cmd + ": instantiated");
            return;
        }
        if cmd == "assert_unlinkable" and wasm_link_error() == "" {
            _fail(ln, "unlinkable: trapped instead");
        }
        if cmd != "assert_unlinkable" and wasm_link_error() != "" {
            _fail(ln, cmd + ": link error " + wasm_link_error());
        }
        return;
    }
}

with entry {
    _setup_spectest();
    i: int = 1;
    total_checks: int = 0;
    total_fails: int = 0;
    total_bad: int = 0;
    while i < len(sys.argv) {
        path: str = sys.argv[i];
        _SUITE = path;
        slash: int = path.rfind("/");
        if slash >= 0 {
            _SUITE = path[slash + 1:];
        }
        _CHECKS = 0;
        _FAILS = 0;
        _HAVE_CUR = False;
        _NAMED = {};
        text: str = _read_text(path);
        if _READ_FAILED {
            print("spec/" + _SUITE + ": cannot read " + path);
            total_bad = total_bad + 1;
            i = i + 1;
            continue;
        }
        for line in text.split("\n") {
            _run_line(line);
        }
        print(
            "spec/"
                + _SUITE
                + ": "
                + str(_CHECKS)
                + " checks, "
                + str(_FAILS)
                + " failures"
        );
        total_checks = total_checks + _CHECKS;
        total_fails = total_fails + _FAILS;
        i = i + 1;
    }
    # The CI lane gates on the exit status, so failed checks and unreadable
    # inputs must both fail the run, not just print. _exit skips the atexit
    # flush, so push stdout out first.
    if total_fails > 0 or total_bad > 0 {
        fflush(0);
        _exit(1);
    }
}
