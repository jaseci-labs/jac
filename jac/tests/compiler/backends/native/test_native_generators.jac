"""Behavioral tests for generator functions (yield) on native.

Graduated from the YieldExpr hard reject in the capability gate: a `def`
containing `yield` lowers to a JacIter creation function plus a private
resume state machine. Consumers exercise the existing iterator surface:
for-loops, first-class next(), independent instances, early break (frame
drop), and composition through the lazy adapters.
"""

import ctypes;
import os;
import from tests.support {
    TESTS_DIR,
    compile_native,
    get_func,
    has_error_code,
    native_address,
    native_force_opts
}
import jaclang;

import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

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
    keepalive: list = [];
    def _call(*args: any) -> any {
        c_args: list = [];
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

"""Compile a snippet through the native pipeline and return the program."""
def compile_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES, f"_gen_{label}.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code, options=native_force_opts());
    return prog;
}

test "generator: for-loop drives a while/yield state machine" {
    (eng, _) = compile_native("generators.jac");
    f = get_func(eng, "total_of", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 10 , "0+1+2+3+4";
    assert f(0) == 0 , "empty generator yields nothing";
    assert f(1) == 0 , "single yield of 0";
}

test "generator: early break abandons the stream safely" {
    (eng, _) = compile_native("generators.jac");
    f = get_func(eng, "early_break", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(10, 3) == 3 , "sees 0,1,2 then breaks";
}

test "generator: first-class next() advances a stored instance" {
    (eng, _) = compile_native("generators.jac");
    f = get_func(eng, "manual_next", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 1 , "a=0, b=1 -> 0*10+1";
}

test "generator: independent instances do not share frames" {
    (eng, _) = compile_native("generators.jac");
    f = get_func(eng, "two_streams", ctypes.c_int64, ctypes.c_int64);
    # sum over a,b in [0..2]^2 of a*b = (0+1+2)^2 = 9.
    assert f(3) == 9;
}

test "generator: yield inside a for-over-range resumes mid-loop" {
    (eng, _) = compile_native("generators.jac");
    f = get_func(eng, "total_for_yield", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 12 , "0+2+4+6";
}

test "generator: plain return stops iteration early" {
    (eng, _) = compile_native("generators.jac");
    f = get_func(
        eng, "total_stop_early", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert f(10, 4) == 6 , "0+1+2+3 then return";
}

test "generator: str parameter is retained by the frame across yields" {
    (eng, _) = compile_native("generators.jac");
    f = get_sfunc(eng, "echo_len", ctypes.c_int64, ctypes.c_char_p);
    assert f(b"abcd") == 12 , "len('abcd') * 3";
}

test "generator: composes under the lazy map adapter" {
    (eng, _) = compile_native("generators.jac");
    f = get_func(eng, "doubled_total", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 12 , "2*(0+1+2+3)";
}

test "generator: yield from chains generators, lists, and plain yields" {
    (eng, _) = compile_native("generators_residual.jac");
    f = get_func(eng, "total_chain", ctypes.c_int64, ctypes.c_int64);
    assert f(3) == 1302 , "0+1+2 + 100+200 + 999";
    assert f(0) == 1299 , "empty inner generator, then 100+200+999";
}

test "generator: yield from a string yields its characters" {
    (eng, _) = compile_native("generators_residual.jac");
    f = get_sfunc(eng, "count_chars", ctypes.c_int64, ctypes.c_char_p);
    assert f(b"abcd") == 4;
    assert f(b"") == 0;
}

test "generator: bare yield paces iteration" {
    (eng, _) = compile_native("generators_residual.jac");
    f = get_func(eng, "count_pacer", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 5;
    assert f(0) == 0;
}

test "generator: return <value> stops iteration, value discarded on JacIter" {
    (eng, _) = compile_native("generators_residual.jac");
    f = get_func(eng, "total_upto_return", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 3 , "1+2, the returned 70 has no JacIter consumer";
}

test "generator: yield inside a for over a list resumes mid-loop" {
    (eng, _) = compile_native("generators_residual.jac");
    f = get_func(eng, "total_doubles", ctypes.c_int64);
    assert f() == 12 , "2+4+6";
}

test "generator: yield inside a for over dict keys resumes mid-loop" {
    (eng, _) = compile_native("generators_residual.jac");
    f = get_func(eng, "count_keys", ctypes.c_int64);
    assert f() == 3 , "len('a') + len('bb')";
}

test "generator: yield inside a for over a string resumes mid-loop" {
    (eng, _) = compile_native("generators_residual.jac");
    f = get_sfunc(eng, "count_per_char", ctypes.c_int64, ctypes.c_char_p);
    assert f(b"xyz") == 3;
}

test "generator: yield inside try, exception raised and caught across resumes" {
    (eng, _) = compile_native("generators_residual.jac");
    f = get_func(eng, "total_resilient", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 7 , "1+2+4, no exception";
    assert f(1) == 8 , "1, boom caught, 3, 4";
}

test "generator: yield inside finally resumes through both continuations" {
    # #7626 A6: the finally region records its pending continuation in a
    # frame slot, so suspending inside it is legal. Full iteration yields
    # the try value then the finally value (CPython parity).
    (eng, _) = compile_native("generators_finally.jac");
    f = get_func(eng, "sum_yf", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 11 , "yields 5 then 6";
    assert f(10) == 21 , "yields 10 then 11";
}

test "generator: abandoning a yield-in-finally stream drops the frame safely" {
    (eng, _) = compile_native("generators_finally.jac");
    f = get_func(eng, "first_yf", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 10 , "early return abandons the stream without crashing";
}

test "generator: capturing lambda escaping inside a generator frame" {
    # #7626 A2: closure cells for generator locals are allocated in the
    # creation fn and their handles live in frame slots, so a lambda can
    # escape as a value inside a generator body.
    (eng, _) = compile_native("generators_closures.jac");
    f = get_func(eng, "sum_gen_scaled", ctypes.c_int64, ctypes.c_int64);
    assert f(3) == 9 , "g(1)+g(2) with k=3: 3+6";
    assert f(0) == 0;
}

test "generator: plain param after a captured param keeps its own value" {
    # Cell-promoted params leave param_slots, so the creation fn must map
    # remaining plain params by their ORIGINAL signature index -- not by
    # enumeration order -- or `base` here would be stored from k's arg.
    (eng, _) = compile_native("generators_closures.jac");
    f = get_func(eng, "sum_gen_mixed", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(3, 10) == 63 , "g(10)+g(11) with k=3: 30+33";
    assert f(0, 5) == 0;
}

test "generator: capturing lambda as a map callback inside a generator" {
    (eng, _) = compile_native("generators_closures.jac");
    f = get_func(eng, "sum_gen_mapped", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 36 , "11+12+13";
}
