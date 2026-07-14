# Simple Jac app that calls Rust functions through the Rust FFI bridge
# This demonstrates how to import and use Rust-native code from Jac
import from pathlib { Path }
import from jaclang.compiler.rust_bridge { load_bridge }


# ── Find the pre-built scalar bridge .so ──────────────────────────────────
def find_so(name: str) -> str {
    ws = Path(__file__).resolve().parent.parent.parent;
    candidates = [ws / "bridges" / "target" / "release"];
    for dir in candidates {
        for suffix in [".so", ".dylib", ".dll"] {
            p = dir / f"libjac_bridge_{name}{suffix}";
            if p.exists() {
                return str(p);
            }
        }
    }
    raise FileNotFoundError(
        f"libjac_bridge_{name} not found — run: cargo build --release"
    );
}


# ── Load the Rust bridge ──────────────────────────────────────────────────
glob _SO = find_so("scalar"),
     _MOD = load_bridge(_SO),
     _Calc = _MOD.Calc,
     _ScalarError = _MOD.ScalarError;


# ── Application entry point ───────────────────────────────────────────────

# Create a Calc instance using the Rust bridge constructor
with entry {
    with _Calc(42) as calc {
        print("=== Rust Scalar Bridge Demo ===");
        print("");
        print("Seed value:", calc.seed());
        # Basic arithmetic through Rust
        print("Add 10:", calc.add(10));
        print("Add -25:", calc.add(-25));
        # Unsigned operations
        print("Low byte of seed:", calc.low_byte());
        print("Magnitude (unsigned abs):", calc.magnitude());
        # Full-range u64 round-trip
        print("Echo u64(MAX):", calc.echo_u64(0xFFFFFFFFFFFFFFFF));
        print("Max u64:", calc.max_u64());
        # Fallible operation: Result<i64, String> -> raises _ScalarError on Err
        print("Checked div 42/6:", calc.checked_div(6));
        try {
            calc.checked_div(0);
        } except _ScalarError as e {
            print("Caught Rust error: '", str(e), "'");
        }
    }

    # Negative seed to prove signed values survive the FFI boundary
    with _Calc(-7) as calc2 {
        print("");
        print("=== Negative Seed ===");
        print("Seed:", calc2.seed());
        print("Magnitude (unsigned_abs):", calc2.magnitude());
        print("low_byte(-1):");
    }
    with _Calc(-1) as calc3 {
        print("  seed:", calc3.seed());
        print("  low_byte:", calc3.low_byte(), "(expect 255 for -1 & 0xff)");
    }

    print("");
    print("Done! Rust functions called successfully from Jac.");
}
