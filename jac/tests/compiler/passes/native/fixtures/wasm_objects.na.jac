"""Single fixture exercising the wasm linker's full object->module transform:
objects + lists (malloc/memcpy imports, indirect-call table + elem, every
relocation kind), and a mutable global (data segment + memory-addr relocs +
cross-call persistence). The point under test is the linker, not the math."""

obj Pt { has x: float, y: float, alive: bool; }

glob calls: int = 0;

def make(n: int) -> list[Pt] {
    out: list[Pt] = [];
    i = 0;
    while i < n {
        out.append(Pt(x=float(i), y=float(i) * 2.0, alive=True));
        i += 1;
    }
    return out;
}

def sum_x(pts: list[Pt]) -> float {
    global calls;
    calls = calls + 1;
    total = 0.0;
    i = 0;
    while i < len(pts) {
        p = pts[i];
        if p.alive { total += p.x; }
        i += 1;
    }
    return total;
}

def demo(n: int) -> float { return sum_x(make(n)); }
def call_count() -> int { return calls; }
