"""CPython/ctypes side of the serde wide lane (FFI-LANES-PLAN 2.5).

The na surface has no `any` type, so it models a wide value as a `JacValue`
tagged union (see test_rust_wide_lane.jac). CPython is dynamically typed, so the
ctypes bridge decodes a wide MessagePack payload straight to native
dict/list/int/float/str/bool/None and encodes the same natives back. These tests
exercise that codec and the `_wire` argtype plumbing directly — no Rust
toolchain / .so needed.
"""

import from ctypes { c_char_p, c_uint32, c_uint64 }
import from jaclang.compiler.rust_bridge._blob {
    FnDesc,
    ParamDesc,
    RecordDesc,
    FieldDesc,
    TAG_WIDE,
    TAG_INT,
    TAG_STR,
    TAG_VOID,
    FN_METHOD
}
import from jaclang.compiler.rust_bridge._marshal { classify, SlotKind }
import from jaclang.compiler.rust_bridge._ctypes_codegen {
    _mp_encode,
    _mp_decode,
    _ret_bridgeable,
    _wire,
    _make_record_class,
    _rec_to_dict
}


def _point_rec -> RecordDesc {
    return RecordDesc(
        index=0,
        name="Point",
        fields=[
            FieldDesc(name="x", tag=TAG_INT),
            FieldDesc(name="y", tag=TAG_INT),
            FieldDesc(name="label", tag=TAG_STR)
        ]
    );
}


test "a typed record class round-trips through the msgpack codec" {
    rec = _point_rec();
    cls = _make_record_class(rec);
    p = cls(x=1, y=2, label="origin");
    # typed attribute access
    assert p.x == 1 and p.y == 2 and p.label == "origin";
    # value equality + a readable repr
    assert p == cls(x=1, y=2, label="origin");
    assert "Point(" in repr(p);
    # instance -> dict projects onto the declared fields
    d = _rec_to_dict(p, rec);
    assert d == {"x": 1, "y": 2, "label": "origin"};
    # a dict passes through unchanged (ergonomic: callers may pass a dict)
    assert _rec_to_dict({"x": 9}, rec) == {"x": 9};
    # the projected dict encodes/decodes byte-identically to the dynamic path
    got = _mp_decode(_mp_encode(d));
    assert got == {"x": 1, "y": 2, "label": "origin"};
}


class _MockCFn {
    with entry {
        argtypes = None;
        restype = None;
    }
}


class _MockLib {
    def __getattr__(self: _MockLib, name: str) -> object {
        return _MockCFn();
    }
}


test "native scalars round-trip through the wide codec" {
    for v in [None, True, False, 0, 1, 127, -1, -32, 1000, -1000, 3.25, "hi", ""] {
        assert _mp_decode(_mp_encode(v)) == v , v;
    }
}


test "nested containers round-trip through the wide codec" {
    doc = {
        "name": "widget",
        "count": 3,
        "ratio": 0.5,
        "tags": ["a", "b"],
        "nested": {"ok": True, "empty": None, "items": [1, 2, 3]}
    };
    assert _mp_decode(_mp_encode(doc)) == doc;
}


test "wide encoding is byte-identical to the na codec golden" {
    # test_rust_wide_lane / _msgpack.jac verified this exact document natively.
    doc = [1, "hi", {"k": [True, None]}];
    got = _mp_encode(doc);
    expect = bytes([0x93, 0x01, 0xa2, 0x68, 0x69, 0x81, 0xa1, 0x6b, 0x92, 0xc3, 0xc0]);
    assert got == expect , got.hex();
    # a wide-i64 negative uses the 0xd3 + big-endian i64 form.
    assert _mp_encode(-1000) == bytes([0xd3]) + (-1000).to_bytes(8, "big", signed=True);
}


test "the ctypes decoder reads the na encoder's non-minimal int widths" {
    # na always emits 0xd3(i64) for out-of-fixint ints, incl. positives.
    wide_pos = bytes([0xd3]) + (1000).to_bytes(8, "big", signed=True);
    assert _mp_decode(wide_pos) == 1000;
    # unsigned above i64 comes back as a Python int (0xcf u64).
    big = 0x8000000000000001;
    assert _mp_decode(bytes([0xcf]) + big.to_bytes(8, "big")) == big;
}


test "float payloads survive as native floats (no bit-pattern dance)" {
    # Unlike na — which carries floats as an i64 bit pattern — CPython keeps them.
    assert _mp_decode(_mp_encode(3.25)) == 3.25;
    # the na codec may hand us an f32 (0xca); we widen it natively.
    assert _mp_decode(bytes([0xca, 0x40, 0x48, 0x00, 0x00])) == 3.125;
}


test "a wide slot is bridgeable, not skipped" {
    assert _ret_bridgeable(classify(TAG_WIDE)) == True;
    opt_wide = classify(TAG_WIDE);
    opt_wide.is_opt = True;
    assert _ret_bridgeable(opt_wide) == True;
}


test "wire threads a wide param as (char_p, uint32) and a wide return as a buffer" {
    echo = FnDesc(
        index=0,
        name="echo",
        sym="jac_t_widget_echo",
        self_type=0,
        kind=FN_METHOD,
        throws=0,
        ret=TAG_WIDE,
        params=[ParamDesc(name="v", tag=TAG_WIDE)]
    );
    c_fn = _wire(_MockLib(), echo);
    # self handle + (payload ptr, payload len) + out-buffer ptr + out-err ptr.
    assert len(c_fn.argtypes) == 5 , len(c_fn.argtypes);
    assert c_fn.argtypes[0] == c_uint64;
    assert c_fn.argtypes[1] == c_char_p;
    assert c_fn.argtypes[2] == c_uint32;
}


test "the wide codec rejects non-string map keys and unknown types" {
    got_key_err = False;
    try {
        _mp_encode({1: "no"});
    } except TypeError {
        got_key_err = True;
    }
    assert got_key_err;

    got_type_err = False;
    try {
        _mp_encode(object());
    } except TypeError {
        got_type_err = True;
    }
    assert got_type_err;
}
