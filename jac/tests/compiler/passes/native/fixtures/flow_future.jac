"""General parallel flow calls: `h = flow f(x)` spawns a real task
when every use of the handle is a `wait`, and `wait h` joins and
yields the result. Output is byte-identical to the sequential
lowering across gc modes and thread interleavings."""

def work(seed: int, n: int) -> int {
    t = seed;
    for i in range(n) {
        t = (t * 31 + i) % 1000003;
    }
    return t;
}

def scale(x: float) -> float {
    return x * 1.5;
}

with entry {
    h1 = flow work(1, 200000) ;
    h2 = flow work(2, 200000) ;
    h3 = flow work(3, 200000) ;
    hf = flow scale(4.0) ;
    a = wait h1 ;
    b = wait h2 ;
    c = wait h3 ;
    f = wait hf ;
    print((a + b + c) % 1000003);
    print(f);
    print("end");
}
