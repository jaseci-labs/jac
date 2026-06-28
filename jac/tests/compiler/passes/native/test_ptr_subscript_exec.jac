import ctypes;
import os;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

"""Compile a .na.jac fixture; return (prog, ir) without asserting on errors."""
def _compile(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    return (prog, ir);
}

"""ctypes-callable JIT function by name."""
def _getf(eng: object, name: str, restype: object, *argtypes: object) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(restype, *argtypes)(addr);
}

# ─── compile cleanliness ─────────────────────────────────────────────────────
test "ptr subscript fixture compiles with no errors, no E9002 ICE (#6707, #6708)" {
    (prog, _) = _compile("ptr_subscript.na.jac");
    codes = [
        e.code.code
        for e in (prog.errors_had or [])
        if e.code
    ];
    e9002 = [
        c
        for c in codes
        if c == "E9002"
    ];
    assert not e9002 , f"E9002 ICE(s) emitted for clib subscript fixture (annotations not "
    f"stamped): {e9002}";
    assert not prog.errors_had , f"unexpected compile errors: {[
        str(e) for e in prog.errors_had
    ]}";
}

# ─── read path execution (#6708) ─────────────────────────────────────────────
test "ptr subscript read returns correct field values (#6708)" {
    (prog, ir) = _compile("ptr_subscript.na.jac");
    # Guard: fail cleanly on a broken compile rather than calling garbage JIT
    # code (which segfaults the worker).
    assert not prog.errors_had , f"compile errors block execution: {[
        str(e) for e in prog.errors_had
    ]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine produced";

    # Color[4] as raw bytes: element i .r at byte 4*i, .g at byte 4*i+1.
    cbuf = (ctypes.c_uint8 * 16)();
    vals = [(10, 20, 30, 40), (11, 21, 31, 41), (12, 22, 32, 42), (13, 23, 33, 43)];
    for i in range(4) {
        (r, g, b, a) = vals[i];
        cbuf[4 * i] = r;
        cbuf[4 * i + 1] = g;
        cbuf[4 * i + 2] = b;
        cbuf[4 * i + 3] = a;
    }
    cptr = ctypes.cast(cbuf, ctypes.c_void_p);
    rr = _getf(eng, "read_color_r", ctypes.c_int64, ctypes.c_void_p, ctypes.c_int64);
    rg = _getf(eng, "read_color_g", ctypes.c_int64, ctypes.c_void_p, ctypes.c_int64);
    for i in range(4) {
        assert rr(cptr, i) == vals[i][0] , f"read_color_r[{i}] = {rr(
            cptr, i
        )}, expected {vals[i][0]}";
        assert rg(cptr, i) == vals[i][1] , f"read_color_g[{i}] = {rg(
            cptr, i
        )}, expected {vals[i][1]}";
    }

    # Vec2[3]: element i .x at doubles[2*i]. Proves the GEP stride is one whole
    # 16-byte struct, not a fixed 8.
    vbuf = (ctypes.c_double * 6)();
    xs = [1.5, 3.5, 5.5];
    for i in range(3) {
        vbuf[2 * i] = xs[i];
    }
    vptr = ctypes.cast(vbuf, ctypes.c_void_p);
    rvx = _getf(eng, "read_vec2_x", ctypes.c_double, ctypes.c_void_p, ctypes.c_int64);
    for i in range(3) {
        assert rvx(vptr, i) == xs[i] , f"read_vec2_x[{i}] = {rvx(vptr, i)}, expected {xs[
            i
        ]}";
    }
}

# ─── write path execution (#6707) ────────────────────────────────────────────
test "ptr subscript write stores into the right element, neighbors intact (#6707)" {
    (prog, ir) = _compile("ptr_subscript.na.jac");
    assert not prog.errors_had , f"compile errors block execution: {[
        str(e) for e in prog.errors_had
    ]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine produced";

    cbuf = (ctypes.c_uint8 * 16)();
    cptr = ctypes.cast(cbuf, ctypes.c_void_p);
    wc = _getf(
        eng,
        "write_color",
        None,
        ctypes.c_void_p,
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.c_int64
    );
    wc(cptr, 2, 99, 88, 77, 66);
    assert [cbuf[k] for k in range(8, 12)] == [99, 88, 77, 66] , f"write_color did not store at element 2: {[
        cbuf[k] for k in range(8, 12)
    ]}";
    assert all(
        cbuf[k] == 0
        for k in range(16)
        if k < 8 or k >= 12
    ) , "write_color spilled outside element 2";
}
