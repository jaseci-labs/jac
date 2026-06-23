"""Clib struct pointer subscript read/write (#6707, #6708).

buf[i] on a named struct pointer must GEP + load (read) or GEP + store (write).
The single-index GEP advances by one whole struct, giving true array semantics.

Uses a logical `import from m { ... }` (not a pinned absolute path) so compile
and JIT paths work across Linux/macOS/Windows triples. No libm functions are
called; the import only declares struct layouts for the subscript tests.
"""

import from m {
    obj Color { has r: u8, g: u8, b: u8, a: u8; }
    obj Vec2  { has x: f64, y: f64; }
}

# -- Reads (#6708) -----------------------------------------------------------

def:pub read_color_r(buf: Color, i: int) -> int {
    c: Color = buf[i];
    return c.r;
}

def:pub read_color_g(buf: Color, i: int) -> int {
    c: Color = buf[i];
    return c.g;
}

def:pub read_vec2_x(buf: Vec2, i: int) -> float {
    v: Vec2 = buf[i];
    return v.x;
}

# -- Writes (#6707) ----------------------------------------------------------

def:pub write_color(buf: Color, i: int, r: int, g: int, b: int, a: int) -> None {
    c = Color(r=r, g=g, b=b, a=a);
    buf[i] = c;
}

with entry {}
