"""Fixture for the na->wasm host-contract tests (test_wasm_build.jac).

Deliberately exercises the parts of the floor that used to leak libc env
imports (#7048): float formatting (snprintf/strtod chain), string
concatenation (malloc/free/strcpy/strcat churn through the in-module
allocator), strlen via len(), and console output through the jac_host1
write(fd, ptr, len) contract.
"""

def compute(n: int) -> int {
    s = "x";
    i = 0;
    while i < n {
        s = s + "y";
        i += 1;
    }
    return len(s);
}

with entry {
    print(3.14);
    print(compute(10));
    print("UP".lower());
}
