"""String-operations oracle kernel.

Exercises the full native string surface -- literals, f-strings, concat,
slices, indexing, comparison, membership, the method set, int round-trip,
dict[str] keys, list[str] grow, borrows of strings -- under ownership
annotations. This is the migration oracle for any change to the string
representation (fat descriptors, zero-copy views): the digest must stay
byte-identical across gc modes and representations, and the enforced
build must stay assert-no-rc-compilable.
"""

import sys;
import time;

def mix(acc: int, s: &str) -> int {
    h = acc;
    for i in range(len(s)) {
        h = (h * 131 + ord(s[i])) % 1000000007;
    }
    return h;
}

def build_word(seed: int) -> str {
    letters: own str = "abcdefghij";
    w: own str = "";
    s = seed;
    for i in range(6) {
        s = (s * 1103515245 + 12345) % 2147483648;
        w = w + letters[s % 10];
    }
    return w;
}

def run(n: int, reps: int) -> int {
    total = 0;
    for r in range(reps) {
        words: list[str] = [];
        for i in range(n) {
            words.append(build_word(i + r * 7 + 1));
        }
        h = 1;
        for i in range(len(words)) {
            w = words[i];
            h = mix(h, &w);
            up = w.upper();
            h = mix(h, &up);
            piece = w[1:4];
            h = mix(h, &piece);
            tail = w[-2:];
            h = mix(h, &tail);
            fs = f"{w}:{i}";
            h = mix(h, &fs);
            if w.startswith("a") {
                h = (h * 3 + 1) % 1000000007;
            }
            if w.endswith("j") {
                h = (h * 5 + 2) % 1000000007;
            }
            if "cd" in w {
                h = (h * 7 + 3) % 1000000007;
            }
            h = (h + w.find("e") + 2) % 1000000007;
            h = (h + w.count("a")) % 1000000007;
            if w < "m" {
                h = (h + 11) % 1000000007;
            }
            if w == up.lower() {
                h = (h + 13) % 1000000007;
            }
        }
        joined = "-".join(words[0:8]);
        h = mix(h, &joined);
        parts = joined.split("-");
        h = (h + len(parts)) % 1000000007;
        rejoined = "".join(parts);
        h = mix(h, &rejoined);
        swapped = joined.replace("-", "_");
        h = mix(h, &swapped);
        trimmed = ("  " + words[0] + "  ").strip();
        h = mix(h, &trimmed);
        num = str(h % 100000);
        back = int(num);
        h = (h + back) % 1000000007;
        seen: dict[str, int] = {};
        for i in range(len(words)) {
            k = words[i][0:2];
            if k in seen {
                seen[k] = seen[k] + 1;
            } else {
                seen[k] = 1;
            }
        }
        h = (h + len(seen)) % 1000000007;
        total = (total + h) % 1000000007;
    }
    return total;
}

with entry {
    n = 200;
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
    print("strops:" + str(total));
    print("ns=" + str(t1 - t0));
}
