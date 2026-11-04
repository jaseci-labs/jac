"""An included platform module: C externs, a glob and annexed helpers."""

import from "libc.so.6" {
    def strlen(s: str) -> int;  def calloc(n: int, size: int) -> int;  def free(
        ptr: int
    ) -> None;
}

glob g_bias: int = 1;

def assert_abi -> int;

def plat_scratch -> int;
