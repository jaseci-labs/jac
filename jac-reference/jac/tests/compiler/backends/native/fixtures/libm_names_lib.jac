"""A separately compiled module calling `math` functions named after libm symbols.

`math.sqrt`, `math.sin`, `math.atan2` and friends share their names with the
libm externs that `_math_native` declares. Those extern names reach `math`'s
clib metadata, and its exported native layout used to drop every `math`
function with such a name, so an importer compiled as its own unit saw them as
demoted.
"""
import math;

obj Arrow {
    has x: float = 0.0,
        y: float = 0.0;

    def length -> float {
        return math.sqrt(self.x * self.x + self.y * self.y);
    }
}

def heading(angle: float) -> float {
    return math.atan2(math.sin(angle), math.cos(angle));
}

def curve(t: float) -> float {
    return math.tan(t) + math.exp(t) - math.log(1.0 + t) + math.hypot(t, 1.0);
}
