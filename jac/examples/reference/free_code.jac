"""Free code: Entry blocks for top-level executable code."""

import math;

obj Circle {
    has radius: float;
    def area -> float {
        return math.pi * self.radius ** 2;
    }
}

def square(n: float) -> float {
    return n ** 2;
}

# Main entry point
with entry {
    print("Free code execution");
    print(square(7));
    print(int(Circle(radius=10).area()));
}

# Named entry point
with entry:custom {
    print("Named entry point");
}
