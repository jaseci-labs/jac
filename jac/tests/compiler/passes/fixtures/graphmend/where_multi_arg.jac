"""Generality: a non-register_buffer callee with TWO differing positional args
and a preserved kwarg; dynamic signal via .argmax(). Both args are merged."""
import torch;

@torch.compile()
def f(t: any, p1: any, q1: any, p2: any, q2: any) -> any {
    if (t.argmax() > 0) {
        combine(p1, q1, mode="x");
    } else {
        combine(p2, q2, mode="x");
    }
    return t;
}
