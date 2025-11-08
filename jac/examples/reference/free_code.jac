import math;

obj circle {
    def init(radius: float) {
        self.radius = radius;
    }

    def area -> float {
        return math.pi * self.radius * self.radius;
    }
}

def foo(n_1: float) {
    return n_1 ** 2;
}

with entry {
    print("Hello World!");
    print(foo(7));
    print(int(circle(10).area()));

    #code block
}
