"""A module that includes `plat` and redeclares some of its C externs."""

import from "libc.so.6" {
    def strlen(s: str) -> int;  def calloc(n: int, size: int) -> int;  def free(
        ptr: int
    ) -> None;
}

include plat;

def measure(s: str) -> int {
    checked: int = assert_abi();
    buf: int = calloc(1, 8);
    held: int = plat_scratch();
    n: int = strlen(s) + checked + g_bias;
    free(buf);
    free(held);
    return n;
}

with entry {
    print(measure("hello"));
}
