"""Behavioral tests for TypeVar-function monomorphization on native.

Graduated from the unlowerable-type E5092 at declaration: a generic def is
a template that emits no code by itself; each callsite's checker-solved
types stamp a specialized private copy, memoized per solved-type key. The
same body lowers to different operations per instantiation.
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

"""Get a descriptor-ABI ctypes callable: c_char_p spellings mean Jac str."""
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

"""Compile a snippet through the native pipeline and return the program."""
def compile_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES, f"_generics_{label}.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code, options=native_force_opts());
    return prog;
}

test "mono: identity specializes at int, float, and str" {
    (eng, _) = compile_native("generics_mono.jac");
    fi = get_func(eng, "use_identity_int", ctypes.c_int64, ctypes.c_int64);
    assert fi(7) == 7;
    fs = get_sfunc(eng, "use_identity_str_len", ctypes.c_int64, ctypes.c_char_p);
    assert fs(b"abcd") == 4;
    ff = get_func(eng, "use_identity_float", ctypes.c_double, ctypes.c_double);
    assert ff(2.5) == 2.5;
    fk = get_func(eng, "use_identity_kw", ctypes.c_int64, ctypes.c_int64);
    assert fk(9) == 9 , "keyword-supplied argument binds the type param";
}

test "mono: one body, different lowerings per instantiation" {
    (eng, _) = compile_native("generics_mono.jac");
    ti = get_func(eng, "use_tail_int", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert ti(3, 9) == 9 , "i64 element load at int";
    ts = get_sfunc(
        eng, "use_tail_str_len", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
    );
    assert ts(b"ab", b"wxyz") == 4 , "pointer element load at str";
}

test "mono: container type params solve through list[T]" {
    (eng, _) = compile_native("generics_mono.jac");
    f = get_func(eng, "use_first", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(5, 9) == 5;
    g = get_sfunc(
        eng, "use_first_str_len", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
    );
    assert g(b"hello", b"xy") == 5;
}

test "mono: an uncalled generic def emits no code and no error" {
    (eng, ir) = compile_native("generics_mono.jac");
    assert native_address(eng, "never_called") == 0 , (
        "a generic template with no instantiations must not exist as a symbol"
    );
}

test "mono: generic generator specializes per element type" {
    # #7626 A3: the generator transform runs under the active substitution
    # with spec-keyed resume/drop symbols, so int and str instantiations
    # of one generic generator coexist.
    (eng, _) = compile_native("generics_generators.jac");
    f = get_func(eng, "sum_int_pairs", ctypes.c_int64);
    assert f() == 6 , "1+2+3 through pairs[int]";
    g = get_func(eng, "count_str_pairs", ctypes.c_int64);
    assert g() == 3 , "len('ab')+len('c') through pairs[str]";
}

test "mono: generic method on an archetype stamps per call site" {
    # #7626 A4: `def pick[T]` on an archetype registers as a method
    # template (no declaration-time unlowerable-type error); call sites
    # stamp self-prepended specializations.
    (eng, _) = compile_native("generics_methods.jac");
    f = get_func(eng, "pick_int", ctypes.c_int64, ctypes.c_int64);
    assert f(1) == 7 , "val>0 picks first";
    assert f(0) == 9 , "val==0 picks second";
    g = get_func(eng, "pick_str_len", ctypes.c_int64, ctypes.c_int64);
    assert g(1) == 2 , "picks 'xx'";
    assert g(0) == 3 , "picks 'yyy'";
}

test "iter flow: generator through a monomorphized Iterator[T] param" {
    # #7626 B4: JacIter is type-erased, so iterator values pass through
    # monomorphized signatures; the element type resolves per site.
    (eng, _) = compile_native("iter_generic.jac");
    f = get_func(eng, "use_take2", ctypes.c_int64);
    assert f() == 1 , "take2(gen_nums(5)) == [0, 1]";
}

test "iter flow: iterator stored in a container and drained later" {
    (eng, _) = compile_native("iter_generic.jac");
    f = get_func(eng, "stored_iter", ctypes.c_int64);
    assert f() == 3 , "0+1+2 through the stored iterator";
}

test "iter flow: lazy adapter over a passed-in iterator param" {
    (eng, _) = compile_native("iter_generic.jac");
    f = get_func(eng, "use_adapter", ctypes.c_int64);
    assert f() == 6 , "map(+1) over gen_nums(3): 1+2+3";
}

test "mono as-value: concrete Callable annotation stamps the template (#7626 A5)" {
    (eng, _) = compile_native("generics_as_value.jac");
    f = get_func(eng, "use_pick_int", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 7 , "pick2[int] through the closure value returns x";
    g = get_func(eng, "use_pick_str_len", ctypes.c_int64);
    assert g() == 3 , "pick2[str] picks 'abc'";
}

test "mono guardrail: a generic function used as a value stays rejected" {
    path = os.path.join(FIXTURES, "_generics_generic_as_value.jac");
    prog = JacProgram();
    ir = prog.compile(
        file_path=path,
        use_str="def pick[T](x: T) -> T {\n"
        "    return x;\n"
        "}\n"
        "def use_it(v: int) -> int {\n"
        "    f = pick;\n"
        "    return f(v);\n"
        "}\n",
        options=native_force_opts()
    );
    assert not prog.errors_had , (
        f"the generic-as-value refusal is owned by use_it(), which must "
        f"demote to a seam, got: {[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    assert "use_it" not in ir.gen.native_layout.functions , (
        "a generic fn used as a value must demote its function out of the "
        "native layout, never lower wrongly"
    );
}
