"""str arguments and returns cross the clib membrane through the JacStr
descriptor shims: wrap to the descriptor, unwrap to a NUL-terminated
char* for C, and wrap-raw the C return back in. Behavior is identical
in every gc mode; the shims are the step-2 scaffolding of the
fat-descriptor migration."""

import from c { def strcmp(a: str, b: str) -> i32;  }
import from c { def strchr(s: str, c: i32) -> str;  }

def mk(k: int) -> str {
    base: own str = "alphabeta";
    if k == 0 {
        return base[0:5:1];
    }
    return base[0:3] + "ha";
}

with entry {
    a: own str = mk(1);
    b: own str = mk(0);
    print(strcmp(a, b));
    c: own str = mk(0);
    print(strcmp(c, "beta") < 0);
    tail = strchr("hello", 108);
    print(tail);
    print("end");
}
