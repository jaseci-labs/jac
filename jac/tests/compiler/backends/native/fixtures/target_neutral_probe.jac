import os;
import sys;

def ratio(a: complex, b: complex) -> complex {
    return a / b;
}

def total(count: i32, *args: VaList) -> f64 {
    acc = 0.0;
    for i in range(int(count)) {
        acc += args.arg(f64);
    }
    return acc;
}

with entry {
    print(sys.platform, file=sys.stderr);
    sys.stdout.write("listing\n");
    print(len(os.listdir(".")) >= 0);
    print(os.path.isfile(__file__), os.path.isdir("."));
    print(os.path.getsize(__file__) > 0, os.path.getmtime(__file__) > 0.0);
    q = ratio(complex(1.0, 2.0), complex(3.0, -4.0));
    print(q.real, q.imag);
    print(total(i32(2), 1.5, 2.25));
}
