import sys;
import time;

obj Node {
    has left: Node | None = None,
        right: Node | None = None;
}

obj Probe {
    has tag: int = 0;

    def drop {
        print("drop:" + str(self.tag));
    }
}

def make(depth: int) -> Node {
    n: own Node = Node();
    if depth > 0 {
        n.left = make(depth - 1);
        n.right = make(depth - 1);
    }
    return n;
}

def check(n: &Node) -> int {
    total = 1;
    if n.left is not None {
        total += check(&n.left);
    }
    if n.right is not None {
        total += check(&n.right);
    }
    return total;
}

def run(max_depth: int) {
    stretch: own Node = make(max_depth + 1);
    print("stretch:" + str(check(&stretch)));
    long_lived: own Node = make(max_depth);
    depth = 4;
    while depth <= max_depth {
        iterations = 1 << (max_depth - depth + 4);
        total = 0;
        for i in range(iterations) {
            t: own Node = make(depth);
            total += check(&t);
        }
        print(
            "depth:" + str(depth) + " trees:" + str(iterations) + " check:" + str(total)
        );
        depth += 2;
    }
    print("longlived:" + str(check(&long_lived)));
}

def drop_witness {
    a: own Probe = Probe(tag=1);
    b: own Probe = Probe(tag=2);
    print("use:" + str(b.tag));
    print("use:" + str(a.tag));
}

with entry {
    n = 10;
    if len(sys.argv) > 1 {
        n = int(sys.argv[1]);
    }
    t0 = time.perf_counter_ns();
    run(n);
    t1 = time.perf_counter_ns();
    drop_witness();
    print("ns=" + str(t1 - t0));
}
