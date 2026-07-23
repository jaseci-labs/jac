"""C narrow signed returns sign-extend at the widening seam (#7626 C2).

`strcmp` returns a C `int` (i32); a negative result must stay negative
when it widens to Jac's 64-bit int or boxes into `any`. Before the sext
seam, the zero-extending coercion turned -1 into 4294967295.
"""

import from c { def strcmp(a: str, b: str) -> i32;  }

def neg_direct -> int {
    return strcmp("a", "b");
}

def neg_thru_any -> int {
    v: any = strcmp("a", "b");
    w: int = v;
    if w < 0 {
        return 1;
    }
    return 0;
}

def pos_direct -> int {
    return strcmp("b", "a");
}
