"""Clib extern declarations are FFI contracts, not ownership-world code: their
params (native width scalars, and even str) must not trip E1401/E1404 in a
nogc-enforced module, and a width-typed local (f32 call result) is a scalar."""

import from fakegl {
    def InitWindow(width: i32, height: i32, title: str) -> None;  def GetFrameTime -> f32;  def DrawThing(
        x: f32, y: f32
    ) -> None;
}

def tick -> float {
    step = GetFrameTime();
    DrawThing(step, 2.0);
    return float(step);
}

def boot {
    InitWindow(960, 600, "probe");
}
