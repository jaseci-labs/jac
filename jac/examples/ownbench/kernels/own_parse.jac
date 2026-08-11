"""Zero-copy parse kernel (C6).

Tokenizes a synthetic source entirely through step-free slice views of
the borrowed input: scan to a delimiter, take the token as a view,
classify it by keyword compares, char probes, and length. In the
enforced build every per-token operation is allocation-free -- views
are rootless {data, len} descriptors, compares run length-aware memcmp
over descriptor parts, and char probes read through the static char
cache. The digest must be byte-identical across gc modes and the
enforced build must compile --assert-no-rc."""

import sys;
import time;

def build_src(n: int) -> str {
    words: list[str] = [
        "let",
        "fn",
        "if",
        "else",
        "while",
        "return",
        "x1",
        "y22",
        "z333",
        "12345"
    ];
    src: own str = "";
    for i in range(n) {
        src = src + words[i % 10] + " ";
    }
    return src;
}

def tokenize(src: &str) -> int {
    h = 7;
    n = len(src);
    i = 0;
    kw = 0;
    idents = 0;
    nums = 0;
    while i < n {
        j = i;
        while j < n and src[j] != " " {
            j = j + 1;
        }
        if j > i {
            tok = src[i:j];
            if tok == "let"
                or tok == "fn"
                or tok == "if"
                or tok == "else"
                or tok == "while"
                or tok == "return" {
                kw = kw + 1;
            } elif tok[0] >= "0" and tok[0] <= "9" {
                nums = nums + 1;
            } else {
                idents = idents + 1;
            }
            h = (h * 131 + len(tok)) % 1000000007;
            h = (h * 131 + ord(tok[0])) % 1000000007;
            if tok < "m" {
                h = (h + 17) % 1000000007;
            }
        }
        i = j + 1;
    }
    return (((h * 31 + kw * 7) + idents * 3) + nums) % 1000000007;
}

def run(n: int, reps: int) -> int {
    total = 0;
    for r in range(reps) {
        src: own str = build_src(n + r);
        total = (total + tokenize(&src)) % 1000000007;
    }
    return total;
}

with entry {
    n = 400;
    if len(sys.argv) > 1 {
        n = int(sys.argv[1]);
    }
    reps = 3;
    if len(sys.argv) > 2 {
        reps = int(sys.argv[2]);
    }
    t0 = time.perf_counter_ns();
    total = run(n, reps);
    t1 = time.perf_counter_ns();
    print("parse:" + str(total));
    print("ns=" + str(t1 - t0));
}
