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
