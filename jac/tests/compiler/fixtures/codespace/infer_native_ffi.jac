"""Markerless native module: placement inferred from extern-decl imports.

An import whose braces contain C-ABI function declarations is an FFI
surface only the native backend can satisfy, so it seeds NATIVE placement;
the globs, objs, and defs the native code references follow through the
same symbol-graph pull.
"""

import from fakelib { def fl_init(w: i32, h: i32) -> None;  def fl_tick -> f32;  }

glob frame_count: int = 0;

obj Particle {
    has x: float = 0.0,
        y: float = 0.0;
}

def step -> float {
    frame_count += 1;
    p = Particle(x=1.0);
    return p.x + fl_tick();
}

def boot {
    fl_init(800, 600);
}

def:pub server_info -> str {
    return "unrelated";
}
