# Rust FFI Feature Demo — demonstrates multiple Rust bridge capabilities in Jac
# Shows: scalars, regex matching, list returns, map returns, error handling
import from pathlib { Path }
import from jaclang.compiler.rust_bridge { load_bridge }


# ── Bridge loader helper ──────────────────────────────────────────────────
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
    raise FileNotFoundError(f"libjac_bridge_{name} not found");
}


# ── Load all pre-built bridges ────────────────────────────────────────────
glob SCALAR = load_bridge(find_so("scalar")),
     LIST = load_bridge(find_so("list")),
     OWNING = load_bridge(find_so("owning")),
     MAP = load_bridge(find_so("map"));


# ── Demo 1: Integer bridge (scalar) ───────────────────────────────────────
def demo_scalar {
    print("╔══════════════════════════════════════════╗");
    print("║  Rust Scalar Bridge                      ║");
    print("╚══════════════════════════════════════════╝");
    with SCALAR.Calc(100) as calc {
        print("  100 + 7         =", calc.add(7));
        print("  seed            =", calc.seed());
        print("  low_byte        =", calc.low_byte());
        print("  magnitude       =", calc.magnitude());
        # Fallible division
        print("  100 // 6        =", calc.checked_div(6));
        try {
            calc.checked_div(0);
        } except SCALAR.ScalarError as e {
            print("  divide by 0     → error:", str(e));
        }
    }
    with SCALAR.Calc(-1) as neg {
        print("  low_byte(-1)     =", neg.low_byte(), "(255 for -1 & 0xff)");
    }
    print("");
}


# ── Demo 2: Regex bridge (owning wrappers) ────────────────────────────────
def demo_regex {
    print("╔══════════════════════════════════════════╗");
    print("║  Rust Regex Bridge (Owning Wrappers)     ║");
    print("╚══════════════════════════════════════════╝");

    # --- is_match ---
    with OWNING.Regex(r"[A-Z]\w+") as re {
        print("  is_match('Hello'):", re.is_match("Hello"));
        print("  is_match('hello'):", re.is_match("hello"));
    }

    # --- find (returns Option<OwnedMatch>) ---
    with OWNING.Regex(r"\d+") as re {
        found = re.find("abc 12345 xyz");
        if found is not None {
            print("  find: as_str() =", found.as_str());
        }
    }

    # --- named captures ---
    with OWNING.Regex(r"(?P<year>\d{4})-(?P<month>\d{2})") as re {
        caps = re.captures("Date: 2026-07");
        if caps is not None {
            print("  captures year :", caps.name("year"));
            print("  captures month:", caps.name("month"));
            print("  captures day  :", caps.name("day"), "(absent → None)");
        }
    }

    # --- find_iter cursor (pull-queue) ---
    with OWNING.Regex(r"\d+") as re {
        print("  find_iter cursor:");
        cursor = re.find_iter("a1 b22 c333");
        while True {
            m = cursor.next();
            if m is None {
                break;
            }
            print("    match:", m.as_str());
        }
    }

    # --- split drain ---
    with OWNING.Regex(r",\s*") as re {
        print("  split drain:");
        drain = re.split("a, bb,ccc, d");
        while True {
            piece = drain.next();
            if piece is None {
                break;
            }
            print("    piece:", piece);
        }
    }
    print("");
}


# ── Demo 3: Vec→list bridge ──────────────────────────────────────────────
def demo_list {
    print("╔══════════════════════════════════════════╗");
    print("║  Rust Vec→List Bridge                    ║");
    print("╚══════════════════════════════════════════╝");

    with LIST.Store(5) as store {
        print("  list[i64]     :", store.counts());
        print("  list[u64]     :", store.big());
        print("  list[str]     :", store.labels());
        print("  list[bool]    :", store.flags());
        print("  empty list    :", store.none());
    }
    with LIST.Store(0) as empty {
        try {
            empty.checked();
        } except LIST.StoreError as e {
            print("  fallible (empty):", str(e));
        }
    }
    print("");
}


# ── Demo 4: HashMap→dict bridge ──────────────────────────────────────────
def demo_map {
    print("╔══════════════════════════════════════════╗");
    print("║  Rust HashMap→Dict Bridge                ║");
    print("╚══════════════════════════════════════════╝");

    with MAP.Store(3) as t {
        print("  dict[str,int] :", t.counts());
        print("  dict[str,uint]:", t.big());
        print("  dict[str,str] :", t.labels());
        print("  dict[str,bool]:", t.flags());
        print("  empty dict    :", t.none());
    }
    with MAP.Store(0) as empty {
        try {
            empty.checked();
        } except MAP.StoreError as e {
            print("  fallible (empty):", str(e));
        }
    }
    print("");
}


# ── Main entry ────────────────────────────────────────────────────────────
with entry {
    print("━" * 48);
    print("  Jac + Rust FFI: Multi-Bridge Demonstration");
    print("━" * 48);
    print("");

    demo_scalar();
    demo_regex();
    demo_list();
    demo_map();

    print("━" * 48);
    print("  All four Rust bridges demonstrated successfully!");
    print("━" * 48);
}
