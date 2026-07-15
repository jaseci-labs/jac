# End-to-end tests for the integer boundary tags (TAG_INT / TAG_UINT) through the
# CPython ctypes loader, against the hand-written jac-bridge-scalar bridge.
# Proves signed/unsigned params and returns round-trip at every width, that a
# negative value survives as its two's-complement bit pattern, that a full-range
# u64 (high bit set) is decoded unsigned rather than as a negative int, and that
# a fallible integer return raises the bridge's error type.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _fixtures { scalar_so }


glob _SO = scalar_so(),
     _MOD = load_bridge(_SO),
     _Calc = _MOD.Calc,
     _ScalarError = _MOD.ScalarError;


# -- signed returns ------------------------------------------------------------
test "signed seed round-trips" {
    with _Calc(5) as c {
        assert c.seed() == 5;
    }
}

test "negative seed survives the slot" {
    with _Calc(-7) as c {
        assert c.seed() == -7;
    }
}

test "signed min/max seeds" {
    with _Calc(9223372036854775807) as c {
        assert c.seed() == 9223372036854775807;
    }
    with _Calc(-9223372036854775808) as c {
        assert c.seed() == -9223372036854775808;
    }
}

# -- signed param + signed return ----------------------------------------------
test "add with positive and negative deltas" {
    with _Calc(10) as c {
        assert c.add(3) == 13;
        assert c.add(-25) == -15;
        assert c.add(0) == 10;
    }
}

# -- narrow unsigned return ----------------------------------------------------
test "low byte is masked and zero-extended" {
    with _Calc(0x1234) as c {
        assert c.low_byte() == 0x34;
    }
    with _Calc(-1) as c {
        # -1 & 0xff == 0xff; must decode as 255, never as a signed -1.
        assert c.low_byte() == 255;
    }
}

# -- unsigned return that exceeds i64::MAX -------------------------------------
test "magnitude of a negative is unsigned" {
    with _Calc(-7) as c {
        assert c.magnitude() == 7;
    }
    with _Calc(-9223372036854775808) as c {
        # unsigned_abs of i64::MIN is 2**63 — a value with the high bit set that
        # a signed decode would read as negative.
        assert c.magnitude() == 9223372036854775808;
    }
}

test "max_u64 decodes as full unsigned range" {
    with _Calc(0) as c {
        assert c.max_u64() == 0xFFFFFFFFFFFFFFFF;
    }
}

# -- unsigned param + unsigned return (identity) -------------------------------
test "echo_u64 round-trips full range" {
    with _Calc(0) as c {
        assert c.echo_u64(0) == 0;
        assert c.echo_u64(42) == 42;
        assert c.echo_u64(0xFFFFFFFFFFFFFFFF) == 0xFFFFFFFFFFFFFFFF;
        assert c.echo_u64(0x8000000000000000) == 0x8000000000000000;
    }
}

# -- float param + float return (TAG_F64) --------------------------------------
test "add_f64 crosses a double each way bit-for-bit" {
    with _Calc(10) as c {
        assert c.add_f64(0.5) == 10.5;
        assert c.add_f64(-2.25) == 7.75;
        # A value with a long binary expansion — only survives under bit
        # reinterpretation; a numeric truncation would corrupt it.
        import math;
        assert c.add_f64(math.pi) == 10.0 + math.pi;
    }
}

test "echo_f32 widens to the slot and returns exactly" {
    with _Calc(0) as c {
        assert c.echo_f32(0.0) == 0.0;
        # 0.5 is exactly representable in both f32 and f64.
        assert c.echo_f32(0.5) == 0.5;
        assert c.echo_f32(-1.25) == -1.25;
    }
}

test "pi round-trips under bit reinterpretation" {
    with _Calc(0) as c {
        import math;
        assert c.pi() == math.pi;
    }
}

# -- byte-string return (TAG_BYTES), embedded NULs -----------------------------
test "seed_bytes returns the full blob including embedded NULs" {
    with _Calc(0x41) as c {
        b = c.seed_bytes();
        assert isinstance(b, bytes);
        # 5 bytes with NULs at 0 and 3 — a strlen decode would return b"" or
        # b"\x01" (stopping at the first NUL). The explicit len must win.
        assert b == b"\x00\x01\x41\x00\xff";
        assert len(b) == 5;
    }
}

# -- byte-slice param + byte-string return -------------------------------------
test "xor round-trips a NUL-bearing blob both ways" {
    with _Calc(0xff) as c {
        # Input carries embedded NULs; &[u8] must cross by (ptr,len), not strlen.
        src = b"\x00\xff\x00\x10";
        out = c.xor(src);
        assert out == b"\xff\x00\xff\xef";
        assert len(out) == 4;
    }
    with _Calc(0) as c {
        # XOR with 0 is the identity — proves the bytes survive unmodified.
        assert c.xor(b"\x00\x01\x02\x00") == b"\x00\x01\x02\x00";
        assert c.xor(b"") == b"";
    }
}

# -- nullable byte-string return (Option<Vec<u8>>) -----------------------------
test "maybe_bytes signals Some/None in-band" {
    with _Calc(0x7f) as c {
        assert c.maybe_bytes(True) == b"\x00\x7f\x00";
        assert c.maybe_bytes(False) is None;
    }
}

# -- fallible integer return ---------------------------------------------------
test "checked_div returns the quotient" {
    with _Calc(20) as c {
        assert c.checked_div(4) == 5;
        assert c.checked_div(-5) == -4;
    }
}

test "checked_div by zero raises the bridge error" {
    with _Calc(20) as c {
        raised = False;
        try {
            c.checked_div(0);
        } except _ScalarError as e {
            raised = True;
            assert "divide by zero" in str(e);
        }
        assert raised;
    }
}

# -- FN_STATIC associated fns (1.3) --------------------------------------------
# The loader exposes a no-receiver `#[jac(assoc)]` fn as a @staticmethod on the
# type: called with NO handle, its return marshaled by its own tag.
test "from_sum is a static factory returning a fresh handle" {
    with _Calc.from_sum(30, 12) as c {
        assert c.seed() == 42;
    }
}

test "from_sum handle is independent of any receiver" {
    # Called off the class, not an instance; wraps a to_int overflow-safely.
    with _Calc.from_sum(9223372036854775807, 1) as c {
        assert c.seed() == -9223372036854775808;
    }
}

test "answer is a no-param scalar static" {
    assert _Calc.answer() == 42;
}

test "parse is a fallible static constructing on the ok path" {
    with _Calc.parse("  -17 ") as c {
        assert c.seed() == -17;
    }
}

test "parse raises the bridge error on bad input" {
    raised = False;
    try {
        _Calc.parse("not-an-int");
    } except _ScalarError as e {
        raised = True;
        assert "parse" in str(e);
    }
    assert raised;
}
