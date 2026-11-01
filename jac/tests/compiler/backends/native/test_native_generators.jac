"""Behavioral tests for generator functions (yield) on native.

Graduated from the YieldExpr hard reject in the capability gate: a `def`
containing `yield` lowers to a JacIter creation function plus a private
resume state machine. Consumers exercise the existing iterator surface:
for-loops, first-class next(), independent instances, early break (frame
drop), and composition through the lazy adapters.
"""

import ctypes;
import from tests.support { compile_native, get_func, native_address }
import from jaclang.compiler.frontend.codeinfo { HDR_RC_OFF }

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

def get_sfunc(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    # descriptor-ABI variant of get_func: a c_char_p spelling here means a
    # Jac `str` (the by-value {root, data, len} descriptor at the native
    # ABI). LLVM decomposes a by-value descriptor param into three scalar
    # slots, so each str param is declared as (root, data, len) scalars and
    # bytes/str args build their backing storage via jac_str_new; str
    # returns come back as the full bytes of the result string, so existing
    # comparisons keep working.
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    real_res: any = JacStrABI if restype == ctypes.c_char_p else restype;
    str_slots: list[bool] = [];
    real_args: list[any] = [];
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
    keepalive: list[any] = [];
    def _call(*args: any) -> any {
        c_args: list[any] = [];
        for (a, is_str) in zip(args, str_slots) {
            if is_str {
                b = a.encode("utf-8") if isinstance(a, str) else a;
                if mkstr is not None {
                    p = mkstr(b, len(b));
                } else {
                    # modules that never build strings natively (this one only
                    # measures len over a str param) emit no jac_str_new; back
                    # the descriptor with a NUL-terminated ctypes buffer, the
                    # same fallback native_marshal uses. Safe: rc ops verify
                    # the header magic and skip foreign allocations.
                    buf = ctypes.create_string_buffer(b);
                    keepalive.append(buf);
                    p = ctypes.cast(buf, ctypes.c_void_p).value;
                }
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

def iter_refs(it: int) -> int {
    return ctypes.c_int64.from_address(it + HDR_RC_OFF).value;
}

test "generator: a for-loop iterator in a frame slot is released exactly once" {
    # The caller keeps two references to one iterator so an extra release
    # shows up as a count instead of a freed block. Draining a generator
    # whose loop iterates an owned alias, a borrowed parameter, or abandons
    # the loop mid-way must leave the caller's count where it was.
    (eng, _) = compile_native("generators_iter_ownership.jac");
    make = get_func(eng, "make_counter", ctypes.c_void_p, ctypes.c_int64);
    alias = get_func(eng, "alias", ctypes.c_void_p, ctypes.c_void_p);
    drain_owned = get_func(eng, "drain_owned", ctypes.c_int64, ctypes.c_void_p);
    drain_borrowed = get_func(eng, "drain_borrowed", ctypes.c_int64, ctypes.c_void_p);
    first_borrowed = get_func(eng, "first_borrowed", ctypes.c_int64, ctypes.c_void_p);
    for (label, run, expected) in [
        ("owned", drain_owned, 6),
        ("borrowed", drain_borrowed, 6),
        ("abandoned", first_borrowed, 0)
    ] {
        it = make(4);
        assert alias(it) == it;
        before = iter_refs(it);
        assert before == 2 , f"{label}: caller holds two references";
        assert run(it) == expected , label;
        assert iter_refs(it) == before , f"{label}: iterator reference count drifted";
    }
}
