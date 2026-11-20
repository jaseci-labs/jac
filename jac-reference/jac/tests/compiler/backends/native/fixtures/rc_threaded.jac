"""Refcount updates before and after the first thread starts.

`rc_churn` runs while the program is single-threaded, so its retains and
releases take the plain load/add/store path. The entry then starts `flow`
tasks that take and drop the same shared string while the main thread does
too. If the spawn did not switch updates to atomic, lost updates free the
string early and the same-size strings allocated after the joins reuse its
block, so it prints as one of them. The string is built at run time because
a folded literal is immortal and never touches its count.
"""

def rc_churn(n: int) -> int {
    acc: int = 0;
    l: list[str] = [];
    i: int = 0;
    while i < n {
        s: str = "x" + str(i);
        l.append(s);
        acc = acc + len(s);
        i = i + 1;
    }
    i = 0;
    while i < n {
        acc = acc + len(l[i]);
        i = i + 1;
    }
    return acc;
}

def hammer(s: str, n: int) -> int {
    acc: int = 0;
    for i in range(n) {
        l: list[str] = [s, s];
        acc = acc + len(l[0]) + len(l[1]);
    }
    return acc;
}

def seed(n: int) -> int {
    t: int = 0;
    for i in range(n) {
        t = t + i;
    }
    return t;
}

with entry {
    print(rc_churn(1000));
    shared = "shared-" + str(seed(100));
    h1 = flow hammer(shared, 300000) ;
    h2 = flow hammer(shared, 300000) ;
    h3 = flow hammer(shared, 300000) ;
    m = hammer(shared, 300000);
    a = wait h1 ;
    b = wait h2 ;
    c = wait h3 ;
}

glob junk: list[str] = [];
with entry {
    for i in range(20000) {
        junk.append("q" + str(100000 + i));
    }
    print(a + b + c + m);
    print(shared);
    print("end");
}
