"""Loop-body reference locals released at the end of every iteration.

Each branch of the loop peeks the next item through its own local, so an
iteration assigns at most one of them. The latch releases the assigned one
and should skip the rest cheaply.
"""

obj Ins {
    has op: int = 0,
        arg: int = 0;
}

obj Tok {
    has id: int = 0;

    def drop {
        print("drop " + str(self.id));
    }
}

def make_code(n: int) -> list[Ins] {
    code: list[Ins] = [];
    for i in range(n) {
        code.append(Ins(op=(i * 7) % 4, arg=i % 13));
    }
    return code;
}

def branch_locals_sum(n: int, rounds: int) -> int {
    code = make_code(n);
    acc: int = 0;
    r: int = 0;
    while r < rounds {
        ip: int = 0;
        while ip < n - 1 {
            op: int = code[ip].op;
            ip = ip + 1;
            if op == 0 {
                p0: Ins = code[ip];
                acc = acc + p0.arg;
            } elif op == 1 {
                p1: Ins = code[ip];
                acc = acc + p1.arg * 2;
            } elif op == 2 {
                p2: Ins = code[ip];
                acc = acc - p2.arg;
            } else {
                p3: Ins = code[ip];
                acc = acc + p3.op;
            }
        }
        r = r + 1;
    }
    return acc;
}

"""Each iteration builds one fresh 1000-char string into one of four branch
locals: 2M iterations allocate ~2 GB in total while only a few are live."""
def churn_strings(n: int) -> int {
    total: int = 0;
    i: int = 0;
    while i < n {
        k: int = i % 4;
        if k == 0 {
            s0: str = "a" * 999 + str(i % 10);
            total = total + len(s0);
        } elif k == 1 {
            s1: str = "b" * 999 + str(i % 10);
            total = total + len(s1);
        } elif k == 2 {
            s2: str = "c" * 999 + str(i % 10);
            total = total + len(s2);
        } else {
            s3: str = "d" * 999 + str(i % 10);
            total = total + len(s3);
        }
        i = i + 1;
    }
    return total;
}

"""A branch local is dropped at the end of the iteration that assigned it,
not when a later iteration reassigns it or the loop exits."""
def drop_order {
    i: int = 0;
    while i < 4 {
        if i % 2 == 0 {
            a: Tok = Tok(id=i);
            print("use " + str(a.id));
        } else {
            b: Tok = Tok(id=i);
            print("use " + str(b.id));
        }
        print("end " + str(i));
        i = i + 1;
    }
    print("after loop");
}

with entry {
    print(branch_locals_sum(400, 50));
    print(churn_strings(2000000));
    drop_order();
    print("end");
}
