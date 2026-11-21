"""String edge cases that crashed or hung (issue #7320 Cluster 3).

A negative repeat count fed a negative size to the allocator (heap
corruption); counting an empty needle never advanced its scan (infinite
hang). CPython: n <= 0 repeats give "", count("") gives len + 1.
"""

def rep(n: int) -> str {
    return "x" * n;
}

def:pub repeat_negative -> int {
    a = 1 if rep(3) == "xxx" else 0;
    b = 1 if rep(0) == "" else 0;
    c = 1 if rep(-2) == "" else 0;
    d = 1 if len(rep(-7)) == 0 else 0;
    return a * 1000 + b * 100 + c * 10 + d;
}

def:pub count_empty_needle -> int {
    s = "abc" + "abc";
    a = s.count("a");
    b = s.count("");
    return a * 100 + b;
}

with entry {
    repeat_negative();
}
