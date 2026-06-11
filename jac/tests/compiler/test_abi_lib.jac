"""Direct unit tests for the pure target-ABI library (Phase 8).

Hand-computed System V AMD64 and AArch64 AAPCS expectations: scalars are
(byte_offset, is_float, bit_width) leaves as produced by the native
pass's struct flattening.
"""
import from llvmlite { ir }
import from jaclang.compiler.targets.abi {
    classify_struct,
    classify_struct_sysv,
    classify_struct_aapcs,
    scalar_layout
}

test "scalar layout primitives" {
    assert scalar_layout(ir.DoubleType()) == (8, 8, [(0, True, 64)]);
    assert scalar_layout(ir.FloatType()) == (4, 4, [(0, True, 32)]);
    assert scalar_layout(ir.IntType(32)) == (4, 4, [(0, False, 32)]);
    assert scalar_layout(ir.IntType(8).as_pointer())[0:2] == (8, 8);
}

test "sysv two ints pack one eightbyte" {
    plan = classify_struct_sysv(8, 4, [(0, False, 32), (4, False, 32)]);
    assert not plan["memory"];
    assert len(plan["coerce"]) == 1;
    assert isinstance(plan["coerce"][0], ir.IntType);
    assert plan["coerce"][0].width == 64;
}

test "sysv two doubles ride two sse eightbytes" {
    plan = classify_struct_sysv(16, 8, [(0, True, 64), (8, True, 64)]);
    assert not plan["memory"];
    assert len(plan["coerce"]) == 2;
    assert isinstance(plan["coerce"][0], ir.DoubleType);
    assert isinstance(plan["coerce"][1], ir.DoubleType);
}

test "sysv two floats vectorize one eightbyte" {
    plan = classify_struct_sysv(8, 4, [(0, True, 32), (4, True, 32)]);
    assert not plan["memory"];
    assert len(plan["coerce"]) == 1;
    assert isinstance(plan["coerce"][0], ir.VectorType);
}

test "sysv mixed int and float eightbyte is integer class" {
    plan = classify_struct_sysv(8, 4, [(0, False, 32), (4, True, 32)]);
    assert not plan["memory"];
    assert len(plan["coerce"]) == 1;
    assert isinstance(plan["coerce"][0], ir.IntType);
}

test "sysv large aggregate is memory byval" {
    plan = classify_struct_sysv(
        24, 8, [(0, False, 64), (8, False, 64), (16, False, 64)]
    );
    assert plan["memory"];
    assert plan["byval"];
}

test "aapcs homogeneous double aggregate" {
    plan = classify_struct_aapcs(24, 8, [(0, True, 64), (8, True, 64), (16, True, 64)]);
    assert not plan["memory"];
    assert len(plan["coerce"]) == 1;
    assert isinstance(plan["coerce"][0], ir.ArrayType);
    assert plan["coerce"][0].count == 3;
    assert plan["safe"];
}

test "aapcs five floats is not an hfa" {
    scalars = [
        (0, True, 32),
        (4, True, 32),
        (8, True, 32),
        (12, True, 32),
        (16, True, 32)
    ];
    plan = classify_struct_aapcs(20, 4, scalars);
    assert plan["memory"];
    assert not plan["byval"];
}

test "aapcs small mixed aggregate rides general registers" {
    plan = classify_struct_aapcs(
        12, 4, [(0, False, 32), (4, True, 32), (8, False, 32)]
    );
    assert not plan["memory"];
    assert len(plan["coerce"]) == 1;
    assert isinstance(plan["coerce"][0], ir.ArrayType);
    assert plan["coerce"][0].count == 2;
}

test "triple dispatch" {
    sysv = classify_struct(
        8, 4, [(0, False, 32), (4, False, 32)], "x86_64-unknown-linux-gnu"
    );
    assert isinstance(sysv["coerce"][0], ir.IntType);
    aapcs = classify_struct(
        8, 4, [(0, False, 32), (4, False, 32)], "aarch64-unknown-linux-gnu"
    );
    assert not aapcs["byval"] or not aapcs["memory"];
    assert aapcs["safe"];
}

test "empty struct is trivial on both abis" {
    s = classify_struct_sysv(0, 1, []);
    a = classify_struct_aapcs(0, 1, []);
    assert not s["memory"] and s["coerce"] == [];
    assert not a["memory"] and a["coerce"] == [];
}
