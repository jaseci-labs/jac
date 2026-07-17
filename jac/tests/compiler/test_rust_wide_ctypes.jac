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
    TAG_WIDE_REC_SHIFT,
    TAG_LIST_BIT,
    TAG_OPT_BIT,
    TAG_MAP_BIT,
    RECORD_KIND_ENUM,
    FN_METHOD
}
import from jaclang.compiler.rust_bridge._marshal { classify, SlotKind }
import from jaclang.compiler.rust_bridge._ctypes_codegen {
    _mp_encode,
    _mp_decode,
    _ret_bridgeable,
    _wire,
    _make_record_class,
    _make_enum_class,
    _rec_to_dict,
    _rec_from_msg,
    _rec_to_msg
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


# ── nested / container / enum typed records (2.9-followup) ──────────────────────

class _FakeRt {
    def init(self: _FakeRt, records: list, record_classes: dict) {
        self.records = records;
        self.record_classes = record_classes;
    }
}


def _wide_ref(rid: int) -> int {
    return TAG_WIDE | (rid << TAG_WIDE_REC_SHIFT);
}


"""A fake runtime holding the geo_demo record graph: Point(0), Region(1),
Path(2), Shape(3-enum)."""
def _geo_rt -> _FakeRt {
    point = RecordDesc(
        index=0,
        name="Point",
        fields=[
            FieldDesc(name="x", tag=TAG_INT),
            FieldDesc(name="y", tag=TAG_INT),
            FieldDesc(name="label", tag=TAG_STR)
        ]
    );
    region = RecordDesc(
        index=1,
        name="Region",
        fields=[
            FieldDesc(name="tl", tag=_wide_ref(1)),
            FieldDesc(name="br", tag=_wide_ref(1))
        ]
    );
    path = RecordDesc(
        index=2,
        name="Path",
        fields=[
            FieldDesc(name="pts", tag=TAG_LIST_BIT | _wide_ref(1)),
            FieldDesc(name="name", tag=TAG_OPT_BIT | TAG_STR),
            FieldDesc(name="weights", tag=TAG_MAP_BIT | TAG_INT)
        ]
    );
    shape = RecordDesc(
        index=3,
        name="Shape",
        fields=[
            FieldDesc(name="Empty", tag=TAG_VOID),
            FieldDesc(name="Dot", tag=_wide_ref(1)),
            FieldDesc(name="Area", tag=_wide_ref(2)),
            FieldDesc(name="Tag", tag=TAG_STR)
        ],
        kind=RECORD_KIND_ENUM
    );
    recs = [point, region, path, shape];
    classes = {
        0: _make_record_class(point),
        1: _make_record_class(region),
        2: _make_record_class(path),
        3: _make_enum_class(shape)
    };
    return _FakeRt(records=recs, record_classes=classes);
}


test "a nested record round-trips as a typed instance through the wide codec" {
    rt = _geo_rt();
    Point = rt.record_classes[0];
    Region = rt.record_classes[1];
    r = Region(tl=Point(x=0, y=0, label="a"), br=Point(x=10, y=10, label="b"));
    # encode (typed -> msgpack shape -> bytes) then decode back to typed
    msg = _rec_to_msg(r, rt.records[1], rt);
    assert msg == {
        "tl": {"x": 0, "y": 0, "label": "a"},
        "br": {"x": 10, "y": 10, "label": "b"}
    } , msg;
    back = _rec_from_msg(_mp_decode(_mp_encode(msg)), rt.records[1], rt);
    assert isinstance(back, Region) and isinstance(back.tl, Point) , "nested field is typed";
    assert back.tl.x == 0 and back.br.y == 10 , repr(back);
    assert back == r;
}


test "container fields (list / optional / map) round-trip typed" {
    rt = _geo_rt();
    Point = rt.record_classes[0];
    Path = rt.record_classes[2];
    p = Path(
        pts=[Point(x=1, y=1, label=""), Point(x=2, y=2, label="")],
        name=None,
        weights={"a": 3, "b": 4}
    );
    msg = _rec_to_msg(p, rt.records[2], rt);
    assert msg["pts"] == [
        {"x": 1, "y": 1, "label": ""},
        {"x": 2, "y": 2, "label": ""}
    ] , msg;
    assert msg["name"] is None and msg["weights"] == {"a": 3, "b": 4} , msg;
    back = _rec_from_msg(_mp_decode(_mp_encode(msg)), rt.records[2], rt);
    assert isinstance(back, Path) , "typed Path";
    assert len(back.pts) == 2 and isinstance(back.pts[0], Point) , "list elements typed";
    assert back.pts[1].x == 2
    and back.name is None
    and back.weights == {"a": 3, "b": 4};
}


test "enum variants (unit / newtype scalar / nested record) round-trip typed" {
    rt = _geo_rt();
    Point = rt.record_classes[0];
    Region = rt.record_classes[1];
    Shape = rt.record_classes[3];

    # unit variant -> bare string on the wire
    unit = Shape(variant="Empty");
    assert _rec_to_msg(unit, rt.records[3], rt) == "Empty";
    assert _rec_from_msg("Empty", rt.records[3], rt) == unit;

    # newtype variant with a nested-record payload -> {variant: payload}
    dot = Shape(variant="Dot", value=Point(x=3, y=4, label="p"));
    dmsg = _rec_to_msg(dot, rt.records[3], rt);
    assert dmsg == {"Dot": {"x": 3, "y": 4, "label": "p"}} , dmsg;
    dback = _rec_from_msg(_mp_decode(_mp_encode(dmsg)), rt.records[3], rt);
    assert dback.variant == "Dot" and isinstance(dback.value, Point) , repr(dback);
    assert dback.value.x == 3 and dback == dot;

    # a deeper nested-record payload (Region inside the enum)
    area = Shape(
        variant="Area",
        value=Region(tl=Point(x=0, y=0, label=""), br=Point(x=5, y=6, label=""))
    );
    aback = _rec_from_msg(
        _mp_decode(_mp_encode(_rec_to_msg(area, rt.records[3], rt))), rt.records[3], rt
    );
    assert isinstance(aback.value, Region) and isinstance(aback.value.br, Point);
    assert aback.value.br.y == 6 and aback == area;

    # String-payload variant
    tag = Shape(variant="Tag", value="hi");
    assert _rec_to_msg(tag, rt.records[3], rt) == {"Tag": "hi"};
    assert _rec_from_msg({"Tag": "hi"}, rt.records[3], rt) == tag;
}
