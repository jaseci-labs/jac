"""Soundness: a branch setup writing a name that also exists at module scope.
Function-scope confinement cannot see module-level readers, so the collision
declines."""
import torch;

glob scale = 1.0;

def read_scale -> float {
    return scale;
}

@torch.compile()
def f(x: any, m: any) -> any {
    if (x.sum() > 0) {
        scale = 2.0;
        m.register_buffer("s", x * scale, persistent=False);
    } else {
        m.register_buffer("s", x * 0.5, persistent=False);
    }
    return x;
}
