"""Soundness: branch values that are provably not tensors. `torch.where`
cannot select a string or a container, so rewriting would turn a working
conditional into a runtime TypeError; both shapes must decline."""
import torch;

@torch.compile()
def f(x: any) -> any {
    if (x.sum() > 0) {
        y = "big";
    } else {
        y = "small";
    }
    return y;
}

@torch.compile()
def g(x: any, name: str) -> any {
    if (x.sum() > 0) {
        return [x, 1];
    } else {
        return "none " + name;
    }
}
