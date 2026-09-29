"""Soundness: branch values that are plain Python scalars. `torch.where`
returns a 0-dim tensor, so predicating these turns an int, a bool or a float
into a tensor for every non-tensor consumer (f-string, dict value, `is`, a
plain-Python API); all three shapes must decline. A scalar operand inside a
tensor expression is unaffected: `b * -1` is still a tensor."""
import torch;

@torch.compile()
def f(x: any) -> any {
    if (x.sum() > 0) {
        n = 1;
    } else {
        n = 2;
    }
    return f"count {n}";
}

@torch.compile()
def g(x: any) -> any {
    if (x.sum() > 0) {
        ok = True;
    } else {
        ok = False;
    }
    return {"ok": ok};
}

@torch.compile()
def h(x: any) -> any {
    if (x.sum() > 0) {
        return -1;
    } else {
        return 0.5;
    }
}
