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
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness {
    bridge_so,
    I64_MIN,
    jac_str,
    llvm_shim,
    na_int_literal,
    norm_unsigned,
    run_na_probe,
    skip_gate
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
