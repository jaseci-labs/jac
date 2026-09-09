"""String arguments and borrowed C returns cross the shared string boundary.
The interior pointer returned by strchr must survive its temporary argument."""

import from c { def strcmp(a: str, b: str) -> i32;  }
import from c { def strchr(s: str, c: i32) -> str;  }

def mk(k: int) -> str {
    base: own str = "alphabeta";
    if k == 0 {
        return base[0:5:1];
    }
    return base[0:3] + "ha";
}

def borrowed_tail(k: int) -> str {
    return strchr(mk(k), 112);
}

with entry {
    a: own str = mk(1);
    b: own str = mk(0);
    print(strcmp(a, b));
    c: own str = mk(0);
    print(strcmp(c, "beta") < 0);
    tail = strchr("hello", 108);
    print(tail);
    retained: own str = borrowed_tail(1);
    print(retained);
    print("end");
}
