"""Enforcement fences must not fire on scalar-element container shapes:
a `list[float]` return annotation is a type expression (not a container
literal), and a subscript read of a borrowed list is a scalar."""

obj VM {
    has regs: list[int] = [];
}

def load(prog: &list[int], m: &mut VM, pc: int) {
    m.regs.append(prog[pc]);
    m.regs[0] = prog[pc + 1];
}

def build_vec(n: int) -> list[float] {
    v = [];
    for i in range(n) {
        v.append(i / 2.0);
    }
    return v;
}

def run(n: int) -> float {
    m: own VM = VM();
    prog = [7, 8, 9];
    load(&prog, &mut m, 0);
    a = build_vec(n);
    s = 0.0;
    for x in a {
        s += x;
    }
    return s + m.regs[0];
}

with entry {
    print(run(4));
}
