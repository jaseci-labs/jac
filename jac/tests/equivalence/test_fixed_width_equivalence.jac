"""The fixed-width numeric contract holds identically on every lane (#8532).

One fixture, three backends: the server reference, native LLVM, and the
client's ECMAScript. A value or a trap that differs between lanes fails here.
"""

import json;
import from tests.equivalence.xbackend_equiv {
    call_py_fixture,
    compile_fixture_to_js,
    encode_py_wire,
    run_js_expr,
    run_js_function,
    run_py_fixture,
    run_with_both
}

glob EXPECTED: dict[str, any] = {
         "overflow_add": 1,
         "overflow_max": 1,
         "underflow": 1,
         "cast_trap": 1,
         "neg_min": 1,
         "shl_trap": 1,
         "wrap_300": 44,
         "wrap_i8_200": -56,
         "wrapping_add": -56,
         "wrapping_sub": 255,
         "wrapping_mul": 0,
         "wrapping_shl": 128,
         "lshr": 127,
         "ashr": -1,
         "u64_gt": 1,
         "u8_floordiv": 66,
         "u8_mod": 2,
         "i8_floordiv": -4,
         "i8_mod": 1,
         "u32_truediv": 3.5,
         "invert_u8": 255,
         "pow_u8": 128,
         "f32_literal": 0.10000000149011612,
         "f32_sum": 0.30000001192092896,
         "f32_to_f64": 0.10000000149011612,
         "i8_min": -128,
         "u16_max": 65535,
         "widened_u8": 200,
         "literal_adopt": 2,
         "cast_float_trunc": -3,
         "abs_i8": 5,
         "i16_min": -32768,
         "i16_mul": 30000,
         "i16_trap": 1,
         "u16_wrap": 0,
         "u16_shr": 255,
         "u16_inv": 65535,
         "i32_min": -2147483648,
         "i32_mod": 2,
         "i32_neg": -2147483647,
         "u32_inv": 4294967295,
         "u32_trap": 1,
         "u32_and": 4026531840,
         "i64_mul": 1000000000,
         "i64_min_shr": -2147483648,
         "i64_trap": 1,
         "u64_max_shr": 4294967295,
         "u64_trap": 1,
         "u64_floordiv": 3002399751580331,
         "f64_div": 0.25,
         "f64_floor": -4.0,
         "f32_div": 0.25,
         "f32_neg": -1.5,
         "i8_max": 127,
         "u8_min": 0
     };

test "the server lane matches the spec row for row" {
    got = run_py_fixture("fw_conformance", "fw_py");
    assert got == EXPECTED , {
        k: (got.get(k), v)
        for (k, v) in EXPECTED.items()
        if got.get(k) != v
    };
}

test "native and client lanes agree with the server lane" {
    run_with_both(
        "fw_conformance.jac",
        "fw_py",
        "fw_cl",
        "fw_na",
        tolerance=1e-12,
        require=["na", "cl"],
        strict_keys=True
    );
}

glob JSON_WIRE: dict[str, any] = {
         "big": "9223372036854775808",
         "small": 5,
         "neg": -7
     },
     NARROW_EXPECTED: dict[str, any] = {
         "min_floordiv_trap": 1,
         "min_mod": 0,
         "mul_trap": 1,
         "shl_trap": 1,
         "abs_min_trap": 1,
         "i16_shl_trap": 1,
         "u32_max_add": 4294967295,
         "u32_floordiv": 613566756,
         "u32_mod": 3,
         "i32_neg_floordiv": -4,
         "i32_neg_mod": 1,
         "u32_lshr": 2147483647,
         "i32_ashr": -1,
         "u32_shl_ok": 2147483648,
         "u32_and": 1,
         "u32_or": 2147483649,
         "u32_xor": 4294967294,
         "u32_invert": 4294967295,
         "i32_invert": -1,
         "wrap_mul_u32": 0,
         "wrap_mul_i32": -67153019,
         "wrap_add_u32": 0,
         "wrap_shl_u32": 2147483648,
         "wrap_neg_i32": -2147483648,
         "wrap_mul_u8": 88,
         "wrap_neg_one_u32": 4294967295,
         "cast_trunc_pos": 3,
         "cast_trunc_neg": -3,
         "cast_float_zero": 0,
         "u16_edge": 65535
     };

test "the narrow widths match the spec on the server lane" {
    got = run_py_fixture("fw_narrow", "narrow_py");
    assert got == NARROW_EXPECTED , {
        k: (got.get(k), v)
        for (k, v) in NARROW_EXPECTED.items()
        if got.get(k) != v
    };
}

test "the narrow widths agree across the native and client lanes" {
    run_with_both(
        "fw_narrow.jac",
        "narrow_py",
        "narrow_cl",
        "narrow_na",
        require=["na", "cl"],
        strict_keys=True
    );
}

test "a 64-bit value crosses the JSON boundary as a number when safe, else as a string" {
    js = compile_fixture_to_js("fw_conformance.jac");
    assert run_js_function(js, "fw_json_cl") == JSON_WIRE;
}

test "the server lane encodes the same values the same way as the client lane" {
    raw = json.loads(encode_py_wire(call_py_fixture("fw_conformance", "fw_json_py")));
    wire = {
        k: v
        for (k, v) in raw.items()
        if k in JSON_WIRE
    };
    assert wire == JSON_WIRE , raw;
    js = compile_fixture_to_js("fw_conformance.jac");
    assert wire == run_js_function(js, "fw_json_cl") , wire;
}

test "the client encodes through its own replacer, leaving BigInt.prototype alone" {
    js = compile_fixture_to_js("fw_conformance.jac");
    got = run_js_expr(
        js,
        "[typeof BigInt.prototype.toJSON,"
        " _jac.fw.stringify({v: 2n ** 64n}),"
        " _jac.fw.stringify({v: 5n})]"
    );
    assert got == ["undefined", "{\"v\":\"18446744073709551616\"}", "{\"v\":5}"] , got;
}

test "a value that left as a string reads back into its sized type" {
    import from jaclang.data.serializer { Serializer }
    import from jaclang.runtime.sized { SIZED_TYPES }
    u64_cls = SIZED_TYPES["u64"];
    (back, ok) = Serializer.coerce("9223372036854775808", u64_cls);
    assert ok and type(back) is int and back == 9223372036854775808;
    (small, ok2) = Serializer.coerce(5, u64_cls);
    assert ok2 and type(small) is int and small == 5;
}

test "the wire rule touches sized 64-bit values only, not plain ints" {
    import from jaclang.data.serializer { Serializer }
    import from jaclang.runtime.sized { SIZED_TYPES }
    import from tests.equivalence.fixtures.fw_conformance { FwScope }
    big: int = 1 << 60;
    payload = FwScope(
        plain=big,
        narrow=SIZED_TYPES["u32"](4294967295),
        small64=SIZED_TYPES["i64"](-7),
        wide64=SIZED_TYPES["u64"](1 << 60)
    );
    wire = Serializer.serialize(payload, api_mode=True);
    assert wire["plain"] == big and not isinstance(wire["plain"], str);
    assert wire["narrow"] == 4294967295 and not isinstance(wire["narrow"], str);
    assert wire["small64"] == -7 and not isinstance(wire["small64"], str);
    assert wire["wide64"] == str(1 << 60);
    # Persistence keeps the number: Python's ints are lossless on that path.
    kept = Serializer.serialize(payload, api_mode=False);
    assert int(kept["wide64"]) == (1 << 60) and not isinstance(kept["wide64"], str);
}
