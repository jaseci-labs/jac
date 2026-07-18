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


# Byte-string (TAG_BYTES) lane -- na <-> CPython conformance. A `&[u8]` param
# crosses as (data ptr, byte length); a `Vec<u8>` / `Option<Vec<u8>>` return
# crosses as an owned JacBuf read length-explicit (embedded NULs survive -- a
# strlen decode would truncate). Both na-backend gaps that once blocked this are
# fixed (a `bytes` arg lowers to its data pointer for a `bytes`-typed foreign
# param, and a `-> bytes` method call is typed as a bytes object), so `_synth`
# now emits the lane and na is observationally identical to the CPython loader.
#
# Content cases (`want_content=True`: seed_bytes, xor) compare a NUL-safe decimal
# descriptor ("len:b0,b1,.."), built by subscripting -- never by concatenating
# the bytes into a str, which would drop interior NULs on na. `seed_bytes`
# returns [0x00, 0x01, seed, 0x00, 0xff], so its content check already exercises
# leading/interior NUL survival on the length-explicit return.
#
# Option cases (`want_content=False`: maybe_bytes) compare only presence + length
# ("None" vs "some:N"), NOT content: na cannot yet narrow a `bytes | None` value
# to `bytes` to subscript it (a general na union-narrowing gap, unrelated to the
# bridge -- `len()` on the union works, only `v[i]` does not). The in-band None
# channel (null JacBuf ptr) and the Some length are what this case proves; the
# byte content of a nullable return rides the same decoder as `seed_bytes`.
glob BYTES_CASES = [
         (5, "seed_bytes", None, True),
         (255, "seed_bytes", None, True),
         (15, "xor", [16, 32, 48], True),
         (7, "maybe_bytes", True, False),
         (7, "maybe_bytes", False, False)
     ];


def _bytes_label(seed: int, method: str, arg: object) -> str {
    a = "" if arg is None else str(arg);
    return f"{seed} {method}({a}) = ";
}


def _bytes_desc(v: object, want_content: bool) -> str {
    if v is None {
        return "None";
    }
    if not want_content {
        return "some:" + str(len(v));
    }
    # NUL-safe: render each byte as a decimal int, joined with commas.
    d = str(len(v)) + ":";
    for i in range(len(v)) {
        if i > 0 {
            d = d + ",";
        }
        d = d + str(v[i]);
    }
    return d;
}


def _bytes_lit(data: list) -> str {
    # A Jac/na `b"\xHH.."` literal for a list of byte values.
    s = "b\"";
    for x in data {
        s = s + f"\\x{x:02x}";
    }
    return s + "\"";
}


def cpython_bytes_side -> list {
    mod = load_bridge(str(SO));
    calc = mod.Calc;
    lines = [];
    for case in BYTES_CASES {
        seed = case[0];
        method = case[1];
        arg = case[2];
        want_content = case[3];
        label = _bytes_label(seed, method, arg);
        c = calc(seed);
        if method == "seed_bytes" {
            r = c.seed_bytes();
        } elif method == "xor" {
            r = c.xor(bytes(arg));
        } else {
            r = c.maybe_bytes(arg);
        }
        lines.append(label + _bytes_desc(r, want_content));
        c.close();
    }
    return lines;
}


def na_bytes_side -> list {
    probe = ["\nwith entry {"];
    # Per-case variable suffixes: na types a local by its FIRST assignment and the
    # checker enforces reassign-compat, so a `bytes` result (seed_bytes/xor) and a
    # `bytes | None` result (maybe_bytes) must NOT share a name across cases.
    k = 0;
    for case in BYTES_CASES {
        seed = case[0];
        method = case[1];
        arg = case[2];
        want_content = case[3];
        label = _bytes_label(seed, method, arg);
        if method == "seed_bytes" {
            call = "c.seed_bytes()";
        } elif method == "xor" {
            call = "c.xor(" + _bytes_lit(arg) + ")";
        } else {
            call = "c.maybe_bytes(" + ("True" if arg else "False") + ")";
        }
        r = f"_r{k}";
        d = f"_d{k}";
        ix = f"_i{k}";
        probe.append("    c = Calc(" + na_int_literal(seed) + ");");
        probe.append("    " + r + " = " + call + ";");
        probe.append("    if " + r + " is None {");
        probe.append("        print(" + jac_str(label) + " + \"None\");");
        probe.append("    } else {");
        if want_content {
            # Full NUL-safe content descriptor (subscripts a definitely-`bytes`
            # value). Every literal separator is wrapped in `str(..)`: na infers a
            # bare `str + ":"` as `LiteralString` and then refuses to reassign a
            # computed `str` to it, so `str(len(..)) + str(":")` keeps the accumulator
            # honestly typed `str`.
            probe.append("        " + d + " = str(len(" + r + ")) + str(\":\");");
            probe.append("        " + ix + " = 0;");
            probe.append("        while " + ix + " < len(" + r + ") {");
            probe.append("            if " + ix + " > 0 {");
            probe.append("                " + d + " = " + d + " + str(\",\");");
            probe.append("            }");
            probe.append(
                "            " + d + " = " + d + " + str(" + r + "[" + ix + "]);"
            );
            probe.append("            " + ix + " += 1;");
            probe.append("        }");
            probe.append("        print(" + jac_str(label) + " + " + d + ");");
        } else {
            # Presence + length only: na cannot subscript a `bytes | None`, but
            # `len()` on the union is well-typed. Proves the Some/None channel.
            probe.append(
                "        print(" + jac_str(label) + " + \"some:\" + str(len(" + r + ")));"
            );
        }
        probe.append("    }");
        probe.append("    c.close();");
        k += 1;
    }
    probe.append("}");
    return run_na_probe(
        SO, probe, "scalar_bytes_conf.na.jac", "scalar_bytes_conf", strip_blank=True
    );
}


test "bytes na cpython conformance" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_bytes_side() == na_bytes_side();
}


# Structural guard (runs without the shim): the bytes vertical is bridged on na,
# not skipped -- `xor` (&[u8] param + Vec<u8> return), `seed_bytes` (Vec<u8>
# return), `maybe_bytes` (Option<Vec<u8>> return, nullable).
test "na bridges the whole bytes lane (param and return)" {
    if not SO.is_file() {
        return;
    }
    src = synthesize_source(SO);
    assert "def xor(data: bytes) -> bytes {" in src;
    assert "def seed_bytes() -> bytes {" in src;
    assert "def maybe_bytes(want: bool) -> bytes | None {" in src;
    # bytes param passes (data ptr, byte length); return reads length-explicit.
    assert "len(data)" in src;
    assert "__jac_bytes_from_raw(rb[0], rb[1]);" in src;
}
