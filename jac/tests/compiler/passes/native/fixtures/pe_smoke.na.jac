"""Smoke fixture for the PE/COFF link path.

Exercises the import surface the PeLinker must wire up: a string print
(puts/printf), formatted output (snprintf), heap use via a list
(malloc/free/memcpy), and floating point (which makes LLVM reference the
MSVC `_fltused` marker the entry injection must define locally).
"""

def total(xs: list[int]) -> int {
    s = 0;
    for v in xs {
        s += v;
    }
    return s;
}

with entry {
    nums: list[int] = [];
    i = 0;
    while i < 5 {
        nums.append(i * i);
        i += 1;
    }
    print(f"sum = {total(nums)}");
    ratio = 7.0 / 2.0;
    print(f"ratio = {ratio}");
}
