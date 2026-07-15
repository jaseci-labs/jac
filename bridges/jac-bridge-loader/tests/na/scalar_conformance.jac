# Scalar-integer conformance: prove the na and CPython runtimes are
# observationally identical for the integer boundary tags (TAG_INT / TAG_UINT),
# against the SAME libjac_bridge_scalar.so.
#
# na side: synthesize Jac source from the .so's metadata, nacompile it with an
# appended probe that prints one line per observation, run the binary, diff the
# output against the CPython loader.  Gated on the LLVM shim; skips without it.
#
# Width note: the na runtime's `int` is 64-bit SIGNED, so a `u64` >= 2**63
# cannot be a positive Jac int -- na carries it as its two's-complement signed
# image (u64::MAX -> -1).  The conformance claim is that the SAME 64 bits cross
# on both runtimes, so the CPython side is normalized to that signed image
# (`norm_unsigned`) before comparison.  Values within i64 range compare directly.
import struct;
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness {
    bridge_so,
    I64_MIN,
    jac_str,
    llvm_shim,
    na_int_literal,
    norm_unsigned,
    run_na_probe,
    skip_gate,
    synthesize_source
}


glob SO = bridge_so("scalar"),
     SHIM = llvm_shim(),
     # (seed, method, arg) -> arg is None for a no-arg method. Covers signed
     # round-trips (pos/neg, full width), narrow unsigned (low_byte), unsigned
     # high-bit decode (max_u64, magnitude of i64::MIN), and a fallible return.
     CASES = [
         (5, "seed", None),
         (-7, "seed", None),
         (9223372036854775807, "seed", None),
         (I64_MIN, "seed", None),
         (10, "add", 3),
         (10, "add", -25),
         (0x1234, "low_byte", None),
         (-1, "low_byte", None),
         (-7, "magnitude", None),
         (I64_MIN, "magnitude", None),
         (0, "max_u64", None),
         (0, "echo_u64", 42),
         (0, "echo_u64", 9223372036854775807),
         (20, "checked_div", 4),
         (20, "checked_div", 0)
     ];


def _label(seed: int, method: str, arg: object) -> str {
    a = "" if arg is None else str(arg);
    return f"{seed} {method}({a}) = ";
}


def cpython_side -> list {
    mod = load_bridge(str(SO));
    calc = mod.Calc;
    err_cls = mod.ScalarError;
    lines = [];
    for case in CASES {
        seed = case[0];
        method = case[1];
        arg = case[2];
        label = _label(seed, method, arg);
        c = calc(seed);
        fn = getattr(c, method);
        try {
            r = fn() if arg is None else fn(arg);
            lines.append(label + str(norm_unsigned(r)));
        } except err_cls {
            lines.append(label + "ERR");
        }
        c.close();
    }
    return [
        ln
        for ln in lines
        if ln.strip()
    ];
}


def na_side -> list {
    probe = ["\nwith entry {"];
    for case in CASES {
        seed = case[0];
        method = case[1];
        arg = case[2];
        label = _label(seed, method, arg);
        call = f"c.{method}()" if arg is None else f"c.{method}({na_int_literal(arg)})";
        probe.append("    c = Calc(" + na_int_literal(seed) + ");");
        probe.append("    try {");
        probe.append("        r = " + call + ";");
        probe.append("        print(" + jac_str(label) + " + str(r));");
        probe.append("    } except Exception {");
        probe.append("        print(" + jac_str(label + "ERR") + ");");
        probe.append("    }");
        probe.append("    c.close();");
    }
    probe.append("}");
    return run_na_probe(
        SO, probe, "scalar_conf.na.jac", "scalar_conf", strip_blank=True
    );
}


test "scalar na cpython conformance" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_side() == na_side();
}


# Float (TAG_F64) conformance. Compared by the exact 64-bit IEEE image rather
# than the decimal text so the claim is a byte-identical crossing on both
# runtimes, independent of either side's float-to-string formatting. (seed,
# method, arg) -- arg is None for a no-arg method.
#
# Only f64 RETURN cases are exercised here: na miscompiles float function
# parameters, so the synthesizer skips f64-PARAM methods (add_f64, echo_f32) --
# see the "na skips f64-param methods" test below. Their param+return round-trip
# is covered on the CPython loader in test_scalar.jac. `scaled` takes an i64
# param (na-safe) and returns f64, proving the return path with a computed value.
glob F64_CASES = [(0, "pi", None), (10, "scaled", 3), (-7, "scaled", 5)];


def _f64_label(seed: int, method: str, arg: object) -> str {
    a = "" if arg is None else str(arg);
    return f"{seed} {method}({a}) = ";
}


def _f64_bits(v: float) -> int {
    return struct.unpack("<Q", struct.pack("<d", float(v)))[0];
}


def cpython_f64_side -> list {
    mod = load_bridge(str(SO));
    calc = mod.Calc;
    lines = [];
    for case in F64_CASES {
        seed = case[0];
        method = case[1];
        arg = case[2];
        label = _f64_label(seed, method, arg);
        c = calc(seed);
        fn = getattr(c, method);
        r = fn() if arg is None else fn(arg);
        # na's `int` is 64-bit signed, so it prints the bit pattern as its signed
        # image; normalize the CPython u64 the same way (norm_unsigned) so the two
        # sides compare on the identical 64 bits, not their signed/unsigned text.
        lines.append(label + str(norm_unsigned(_f64_bits(r))));
        c.close();
    }
    return lines;
}


def na_f64_side -> list {
    probe = ["\nwith entry {"];
    for case in F64_CASES {
        seed = case[0];
        method = case[1];
        arg = case[2];
        label = _f64_label(seed, method, arg);
        call = f"c.{method}()" if arg is None else f"c.{method}({arg})";
        probe.append("    c = Calc(" + na_int_literal(seed) + ");");
        probe.append("    r = " + call + ";");
        probe.append('    fb = struct.unpack("<Q", struct.pack("<d", r))[0];');
        probe.append("    print(" + jac_str(label) + " + str(fb));");
        probe.append("    c.close();");
    }
    probe.append("}");
    return run_na_probe(
        SO, probe, "scalar_f64_conf.na.jac", "scalar_f64_conf", strip_blank=True
    );
}


test "scalar f64 na cpython conformance" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_f64_side() == na_f64_side();
}


# na miscompiles float function parameters, so the synthesizer must SKIP methods
# that take an f64 param (emitting them would silently return wrong values) while
# still bridging f64-return methods. Proven on the synthesized source shape so it
# runs without the LLVM shim.
test "na skips f64-param methods, keeps f64-return methods" {
    if not SO.is_file() {
        return;
    }
    src = synthesize_source(SO);
    # f64-return methods are bridged.
    assert "def pi(" in src;
    assert "def scaled(" in src;
    # f64-param methods are skipped (na float-arg passing is broken).
    assert "def add_f64(" not in src;
    assert "def echo_f32(" not in src;
}
