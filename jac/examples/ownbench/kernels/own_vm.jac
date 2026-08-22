import sys;
import time;

obj VM {
    has stack: list[int] = [],
        regs: list[int] = [];
}

def exec_prog(prog: &list[int], acc0: int, k0: int, limit: int) -> int {
    m: own VM = VM();
    m.regs.append(acc0);
    m.regs.append(k0);
    m.regs.append(limit);
    pc = 0;
    while True {
        op = prog[pc];
        if op == 0 {
            m.stack.append(prog[pc + 1]);
            pc += 2;
        } elif op == 1 {
            b = m.stack.pop();
            a = m.stack.pop();
            m.stack.append(a + b);
            pc += 1;
        } elif op == 2 {
            b = m.stack.pop();
            a = m.stack.pop();
            m.stack.append(a - b);
            pc += 1;
        } elif op == 3 {
            b = m.stack.pop();
            a = m.stack.pop();
            m.stack.append(a * b);
            pc += 1;
        } elif op == 4 {
            m.stack.append(m.regs[prog[pc + 1]]);
            pc += 2;
        } elif op == 5 {
            m.regs[prog[pc + 1]] = m.stack.pop();
            pc += 2;
        } elif op == 6 {
            c = m.stack.pop();
            if c != 0 {
                pc = prog[pc + 1];
            } else {
                pc += 2;
            }
        } else {
            break;
        }
    }
    return m.regs[0];
}

def run(n: int, reps: int) -> int {
    prog = [4, 1, 4, 1, 3, 4, 0, 1, 5, 0, 4, 1, 0, 1, 1, 5, 1, 4, 1, 4, 2, 2, 6, 0, 7];
    total = 0;
    for r in range(reps) {
        total = (total + exec_prog(&prog, 0, 1, n + 1)) % 1000000007;
    }
    return total;
}

with entry {
    n = 1000;
    if len(sys.argv) > 1 {
        n = int(sys.argv[1]);
    }
    reps = 1000;
    if len(sys.argv) > 2 {
        reps = int(sys.argv[2]);
    }
    t0 = time.perf_counter_ns();
    total = run(n, reps);
    t1 = time.perf_counter_ns();
    print("vm:" + str(total));
    print("ns=" + str(t1 - t0));
}
