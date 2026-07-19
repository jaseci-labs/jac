# Benchmark: Rust `regex` crate via FFI bridge vs Python's built-in `re`.
#
# Same pattern, same haystacks, same iteration count -- measured both ways so we
# can see whether crossing the FFI boundary into the compiled Rust engine
# actually beats CPython's stdlib regex on a realistic bulk-matching workload.
#
#   PYTHONPATH=jac jac run examples/rust-demo/regex_bench.jac
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


glob
     # A non-trivial pattern + a corpus of mixed hits/misses.
     pat = r"(?P<user>\w+)@(?P<host>\w+)\.(com|org|net)",
     haystacks = [
         "contact alice@example.com for details",
         "no email in this line at all, sorry",
         "bob_smith@company.org and carol@team.net both replied",
         "malformed @@ nope not-an-email .com",
         "ping dev-null@localhost (no tld, should miss the .com/org/net)",
         "final one: zeta99@service.net done",

     ],
     N = 200000;

with entry {
    print(f"pattern : {pat}");
    print(f"corpus  : {len(haystacks)} lines, {N} iterations each");
    print(f"total   : {len(haystacks) * N} match calls per engine");
    print("");

    # ── Python stdlib `re` ────────────────────────────────────────────────
    py_re = re.compile(pat);
    py_hits = 0;
    t0 = perf_counter();
    for _ in range(N) {
        for h in haystacks {
            if py_re.search(h) is not None {
                py_hits += 1;
            }
        }
    }
    py_secs = perf_counter() - t0;

    # ── Rust `regex` crate over the FFI bridge ────────────────────────────
    rx = load_bridge(find_so("regex_binder"));
    r = rx.Regex(pat);
    rs_hits = 0;
    t1 = perf_counter();
    for _ in range(N) {
        for h in haystacks {
            if r.matches(h) {
                rs_hits += 1;
            }
        }
    }
    rs_secs = perf_counter() - t1;
    r.close();

    # ── Report ────────────────────────────────────────────────────────────
    print(f"Python  re : {py_secs:8.3f}s   ({py_hits} hits)");
    print(f"Rust FFI   : {rs_secs:8.3f}s   ({rs_hits} hits)");
    print("");
    if rs_secs < py_secs {
        print(f"→ Rust FFI is {py_secs / rs_secs:.2f}x FASTER");
    } else {
        print(f"→ Rust FFI is {rs_secs / py_secs:.2f}x SLOWER");
    }
}
