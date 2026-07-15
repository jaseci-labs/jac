"""Fully-owned real program: RPN evaluator + prime sieve under nogc enforcement.

Must compile clean with --enforce-nogc and produce identical output to a
managed build; under --gc none it must pass --assert-no-rc and run leak-free.
"""

obj Stack {
    has vals: list[int] = [];
}

def push(s: &mut Stack, v: int) {
    s.vals.append(v);
}

def pop(s: &mut Stack) -> int {
    return s.vals.pop();
}

def eval_rpn(prog: &list[int]) -> int {
    st: own Stack = Stack();
    for tok in prog {
        if tok >= 0 {
            push(&mut st, tok);
        } else {
            b = pop(&mut st);
            a = pop(&mut st);
            if tok == -1 {
                push(&mut st, a + b);
            } elif tok == -2 {
                push(&mut st, a - b);
            } else {
                push(&mut st, a * b);
            }
        }
    }
    return pop(&mut st);
}

def sieve(limit: int) -> int {
    flags = [];
    for i in range(limit + 1) {
        flags.append(1);
    }
    count = 0;
    p = 2;
    while p <= limit {
        if flags[p] == 1 {
            count += 1;
            m = p * p;
            while m <= limit {
                flags[m] = 0;
                m += p;
            }
        }
        p += 1;
    }
    return count;
}

def run_all {
    prog1 = [3, 4, -1, 5, -3, 2, -2];
    print(eval_rpn(&prog1));
    total = 0;
    for rep in range(50) {
        prog2 = [rep, 7, -1, 3, -3];
        total += eval_rpn(&prog2);
    }
    print(total);
    print(sieve(1000));
}

with entry {
    run_all();
}
