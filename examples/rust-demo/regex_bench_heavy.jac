# Heavy-per-call benchmark: a pattern that triggers catastrophic backtracking
# in Python's backtracking engine, but stays LINEAR in Rust's finite-automaton
# `regex` crate. Here the work-per-call is large, so it dwarfs FFI overhead.
import from pathlib { Path }
import from time { perf_counter }
import re;
import from jaclang.compiler.rust_bridge { load_bridge }


def find_so(name: str) -> str {
    dir = Path(__file__).resolve().parent.parent.parent / "bridges" / "target" / "release";
    for suffix in [".so", ".dylib", ".dll"] {
        p = dir / f"libjac_bridge_{name}{suffix}";
        if p.exists() {
            return str(p);
        }
    }
    raise FileNotFoundError(f"libjac_bridge_{name} not found");
}


glob pat = r"(a+)+$",  # pathological for backtracking engines
     hay = "a" * 22 + "!",  # forces full backtrack before failing
     N = 3;

with entry {
    print(f"pattern : {pat}");
    print(f"haystack: {len(hay)} chars, {N} iterations");
    print("");

    py_re = re.compile(pat);
    t0 = perf_counter();
    for _ in range(N) {
        py_re.search(hay);
    }
    py_secs = perf_counter() - t0;

    rx = load_bridge(find_so("regex_binder"));
    r = rx.Regex(pat);
    t1 = perf_counter();
    for _ in range(N) {
        r.matches(hay);
    }
    rs_secs = perf_counter() - t1;
    r.close();

    print(f"Python  re : {py_secs:8.4f}s");
    print(f"Rust FFI   : {rs_secs:8.4f}s");
    print("");
    if rs_secs < py_secs {
        print(f"→ Rust FFI is {py_secs / rs_secs:.1f}x FASTER");
    } else {
        print(f"→ Rust FFI is {rs_secs / py_secs:.1f}x SLOWER");
    }
}
