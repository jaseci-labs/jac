"""A heap string stored into a heterogeneous list survives read-back.

A mixed-type list (e.g. `[int, str]`) lowers to tagged jacval element storage:
the container holds `{tag, payload}` values and retains heap payloads through
the tag on store. The original regression (a raw-integer backing store boxing
the pointer invisibly, so the source string was freed at last use while the
escaping list still held it, and the element read back as garbage) stays
pinned by these tests as use-after-free guards: index assignment of a local,
slices directly in a literal, a string argument, and a churn loop that forces
backing-store growth all read back intact. The churn loop additionally runs
under an allocator in-use probe asserting FULL reclamation: every boxed
element is released when its list dies, not merely kept alive.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "hetero_list_str.jac";


def _compile(fixture: str) -> any {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine for {fixture}";
    return eng;
}


def _get(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(restype, *argtypes)(addr);
}


class JacStrABI(ctypes.Structure) {
    # Register view of a by-value JacStr {root, data, len} return. LLVM
    # lowers the aggregate return into scalar return registers; a 16-byte
    # two-pointer struct restype makes libffi read the first two of them,
    # which yields root and data. len rides in the third return register,
    # unreachable through libffi, but Jac string payloads are always
    # NUL-terminated at len so a bounded read is recovered from data.
    has _fields_: list[tuple[str, type]] = [
        ("root", ctypes.c_void_p),
        ("data", ctypes.c_void_p)
    ];
}


def _get_s(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    # descriptor-ABI variant of _get: a c_char_p spelling here means a
    # Jac `str` (the by-value {root, data, len} descriptor at the native
    # ABI). LLVM decomposes a by-value descriptor param into three scalar
    # slots, so each str param is declared as (root, data, len) scalars and
    # bytes/str args build their backing storage via jac_str_new; str
    # returns come back as the full bytes of the result string, so existing
    # comparisons keep working.
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    real_res: any = JacStrABI if restype == ctypes.c_char_p else restype;
    str_slots: list = [];
    real_args: list = [];
    for a in argtypes {
        if a == ctypes.c_char_p {
            str_slots.append(True);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_int64);
        } else {
            str_slots.append(False);
            real_args.append(a);
        }
    }
    raw = ctypes.CFUNCTYPE(real_res, *real_args)(addr);
    sn_addr = 0;
    for sn in ("jac_str_new", "__jac_str_new") {
        try {
            sn_addr = native_address(eng, sn);
        } except Exception {
            sn_addr = 0;
        }
        if sn_addr {
            break;
        }
    }
    mkstr = (
        ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(sn_addr)
            if sn_addr
            else None
    );
    def _call(*args: any) -> any {
        c_args: list = [];
        for (a, is_str) in zip(args, str_slots) {
            if is_str {
                assert mkstr is not None , "jac_str_new not found in JIT engine";
                b = a.encode("utf-8") if isinstance(a, str) else a;
                p = mkstr(b, len(b));
                c_args.append(p);
                c_args.append(p);
                c_args.append(len(b));
            } else {
                c_args.append(a);
            }
        }
        r = raw(*c_args);
        if real_res is JacStrABI {
            if not r.data {
                return b"";
            }
            return ctypes.string_at(r.data);
        }
        return r;
    }
    return _call;
}


test "heap string stored in a heterogeneous list by index assignment survives" {
    eng = _compile(FIXTURE);
    via_local = _get_s(eng, "via_local", ctypes.c_char_p, ctypes.c_char_p);
    # r = [19, ""]; r[1] = s[5:12]; return r[1]  -> the sliced substring intact
    assert via_local(b"u-ca=iso8601").decode("utf-8") == "iso8601";
    assert via_local(b"12345abcdefg").decode("utf-8") == "abcdefg";
}


test "heap slices placed directly in a mixed list literal survive" {
    eng = _compile(FIXTURE);
    a = _get_s(eng, "via_literal_a", ctypes.c_char_p, ctypes.c_char_p);
    b = _get_s(eng, "via_literal_b", ctypes.c_char_p, ctypes.c_char_p);
    # r = [99, s[0:3], s[5:12]]
    assert a(b"u-ca=iso8601").decode("utf-8") == "u-c";
    assert b(b"u-ca=iso8601").decode("utf-8") == "iso8601";
}


test "string passed as an argument and stored in a mixed list survives" {
    eng = _compile(FIXTURE);
    via_arg = _get_s(eng, "via_arg", ctypes.c_char_p, ctypes.c_int64, ctypes.c_char_p);
    assert via_arg(7, b"hello").decode("utf-8") == "hello";
    assert via_arg(0, b"").decode("utf-8") == "";
}


test "many heterogeneous lists in a loop stay consistent (no corruption)" {
    eng = _compile(FIXTURE);
    churn = _get(eng, "churn", ctypes.c_int64, ctypes.c_int64);
    # Each iter builds [i, "v" + str(i)] and sums len(list[1]). "v0".."v9" -> 2,
    # "v10".."v99" -> 3, "v100".."v999" -> 4. Sum over i in [0, 1000):
    #   10*2 + 90*3 + 900*4 = 20 + 270 + 3600 = 3890.
    assert churn(1000) == 3890;
    assert churn(0) == 0;
}


test "hetero list churn reclaims every boxed element (in-use heap)" {
    import sys;
    if not sys.platform.startswith("linux") {
        return;
    }
    try {
        libc = ctypes.CDLL("libc.so.6");
        _fields = [
            (n, ctypes.c_size_t)
            for n in (
                "arena",
                "ordblks",
                "smblks",
                "hblks",
                "hblkhd",
                "usmblks",
                "fsmblks",
                "uordblks",
                "fordblks",
                "keepcost"
            )
        ];
        _MI = type("Mallinfo2", (ctypes.Structure, ), {"_fields_": _fields});
        libc.mallinfo2.restype = _MI;
    } except (OSError, AttributeError) {
        return;
    }
    inuse = lambda { int(libc.mallinfo2().uordblks); };
    eng = _compile(FIXTURE);
    churn = _get(eng, "churn", ctypes.c_int64, ctypes.c_int64);
    for _ in range(3) {
        churn(2000);
    }
    base = inuse();
    for _ in range(40) {
        churn(2000);
    }
    growth = inuse() - base;
    assert growth < 256 * 1024 , (
        f"hetero list churn grew in-use heap by {growth} B -- boxed elements "
        f"are not reclaimed when the list dies"
    );
}
