"""Checker fixture: clib import call shapes must not raise E1051 (#7626 C2).

Inline `import from c { def ... }` declarations carry real FuncSignatures,
so their call sites flow through match_args_to_params like any function;
correctly-arited calls (fixed params, variadic tail, multiple variadic
args) must not surface spurious "Too many positional arguments".
"""

import from c { def access(path: str, mode: i32) -> i32;  }
import from c { def printf(fmt: str, *args: any) -> i32;  }

def use_clib -> int {
    r = access("/tmp", 0);
    printf("plain\n");
    printf("%d\n", 42);
    printf("%d %d %d\n", 1, 2, 3);
    return r;
}
