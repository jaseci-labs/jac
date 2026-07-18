"""Direct unit tests for the pure target-ABI library (Phase 8).

Hand-computed System V AMD64 and AArch64 AAPCS expectations: scalars are
(byte_offset, is_float, bit_width) leaves as produced by the native
pass's struct flattening.
"""
import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.targets.abi {
    classify_struct,
    classify_struct_sysv,
    classify_struct_aapcs,
    scalar_layout,
    classify_foreign_fn
}

# Foreign struct model shaped like targets.foreign.collect_foreign_structs
# output: V2 rides SSE registers, Big is MEMORY class (3 eightbytes).
glob FN_STRUCTS: dict = {
         "V2": [("x", "f64"), ("y", "f64")],
         "Big": [("a", "i64"), ("b", "i64"), ("c", "i64")],

     },
     SYSV: str = "x86_64-unknown-linux-gnu";

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

test "foreign fn plan is none without by-value structs" {
    plan = classify_foreign_fn(FN_STRUCTS, [("x", "f64"), ("s", "str")], "i64", SYSV);
    assert plan is None;
}

test "foreign fn register struct param expands coerce slots" {
    plan = classify_foreign_fn(FN_STRUCTS, [("v", "V2"), ("k", "i64")], None, SYSV);
    assert plan is not None;
    assert not plan["sret"];
    (vp, kp) = plan["params"];
    assert vp["kind"] == "struct_reg" and vp["argpos"] == 0;
    assert len(vp["coerce"]) == 2;
    assert kp["kind"] == "scalar" and kp["tname"] == "i64";
    # Two coerce pieces then the scalar: argpos skips the expansion.
    assert kp["argpos"] == 2;
    assert plan["sig"][0][0] == "coerce" and plan["sig"][2] == ("scalar", 1);
    assert plan["ret"]["kind"] == "scalar" and plan["sig_ret"] == ("scalar", );
}

test "foreign fn memory return promotes sret and shifts argpos" {
    plan = classify_foreign_fn(FN_STRUCTS, [("n", "i32")], "Big", SYSV);
    assert plan is not None;
    assert plan["sret"];
    assert plan["ret"]["kind"] == "sret" and plan["ret"]["sname"] == "Big";
    assert plan["sig"][0] == ("sretptr", "Big");
    assert plan["sig_ret"] == ("void", );
    # The lone scalar parameter sits after the hidden sret pointer.
    assert plan["params"][0]["argpos"] == 1;
}

test "foreign fn memory param is a byval struct pointer" {
    plan = classify_foreign_fn(FN_STRUCTS, [("b", "Big")], "f64", SYSV);
    assert plan is not None and not plan["sret"];
    bp = plan["params"][0];
    assert bp["kind"] == "struct_mem" and bp["byval"];
    assert plan["sig"][0] == ("structptr", "Big");
}

test "foreign fn unnamed params get positional names" {
    plan = classify_foreign_fn(FN_STRUCTS, [(None, "V2"), (None, "i64")], None, SYSV);
    assert plan is not None;
    assert plan["params"][0]["pname"] == "arg0";
    assert plan["params"][1]["pname"] == "arg1";
}
