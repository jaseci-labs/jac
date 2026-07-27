import sys;
import time;

obj Expr {
    has kind: int = 0,
        num: int = 0,
        left: Expr | None = None,
        right: Expr | None = None;
}

def cnst(v: int) -> Expr {
    e: own Expr = Expr(kind=0, num=v);
    return e;
}

def mkvar -> Expr {
    e: own Expr = Expr(kind=1);
    return e;
}

def mkadd(l: own Expr, r: own Expr) -> Expr {
    e: own Expr = Expr(kind=2, left=l, right=r);
    return e;
}

def mkmul(l: own Expr, r: own Expr) -> Expr {
    e: own Expr = Expr(kind=3, left=l, right=r);
    return e;
}

def clone(e: &Expr) -> Expr {
    if e.kind >= 2 and e.left is not None and e.right is not None {
        l = clone(&e.left);
        r = clone(&e.right);
        if e.kind == 2 {
            return mkadd(l, r);
        }
        return mkmul(l, r);
    }
    if e.kind == 1 {
        return mkvar();
    }
    return cnst(e.num);
}

def d(e: &Expr) -> Expr {
    if e.kind >= 2 and e.left is not None and e.right is not None {
        if e.kind == 2 {
            return mkadd(d(&e.left), d(&e.right));
        }
        return mkadd(
            mkmul(d(&e.left), clone(&e.right)), mkmul(clone(&e.left), d(&e.right))
        );
    }
    if e.kind == 1 {
        return cnst(1);
    }
    return cnst(0);
}

def eval_at(e: &Expr, x: int, m: int) -> int {
    if e.kind >= 2 and e.left is not None and e.right is not None {
        l = eval_at(&e.left, x, m);
        r = eval_at(&e.right, x, m);
        if e.kind == 2 {
            return (l + r) % m;
        }
        return (l * r) % m;
    }
    if e.kind == 1 {
        return x % m;
    }
    return e.num % m;
}

def node_count(e: &Expr) -> int {
    if e.kind >= 2 and e.left is not None and e.right is not None {
        return 1 + node_count(&e.left) + node_count(&e.right);
    }
    return 1;
}

def build_poly(k: int) -> Expr {
    e: own Expr = mkadd(mkvar(), cnst(1));
    for i in range(2, k + 1) {
        e = mkmul(e, mkadd(mkvar(), cnst(i)));
    }
    return e;
}

def run(n: int, reps: int) -> int {
    total = 0;
    for r in range(reps) {
        p: own Expr = build_poly(n);
        dp: own Expr = d(&p);
        total = (
            total * 31 + eval_at(&dp, 5, 1000000007) + node_count(&dp)
        ) % 1000000007;
    }
    return total;
}

with entry {
    n = 60;
    if len(sys.argv) > 1 {
        n = int(sys.argv[1]);
    }
    reps = 50;
    if len(sys.argv) > 2 {
        reps = int(sys.argv[2]);
    }
    t0 = time.perf_counter_ns();
    total = run(n, reps);
    t1 = time.perf_counter_ns();
    print("deriv:" + str(total));
    print("ns=" + str(t1 - t0));
}
