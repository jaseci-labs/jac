"""Build millions of f-strings from strings made just for them.

`slice` formats a slice of a string, `upper` an upper-cased copy; each step
measures the result and drops it.
"""
import sys;

def tag(w: str, i: int) -> str {
    return f"{w[1:]}:{i}";
}

def shout(w: str) -> str {
    return f"<{w.upper()}>";
}

with entry {
    mode = sys.argv[1];
    steps = int(sys.argv[2]);
    w = "hello world";
    total = 0;
    if mode == "slice" {
        for i in range(steps) {
            total += len(tag(w, i));
        }
    } else {
        for i in range(steps) {
            total += len(shout(w));
        }
    }
    print(total);
}
