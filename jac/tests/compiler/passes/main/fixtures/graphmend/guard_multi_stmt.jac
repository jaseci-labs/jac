"""Validation guard with a cleanup statement before the raise. The trailing
raise (not a single-statement body) means it is a `val_guard`, not data-dependent
control flow that would drop the cleanup."""
import torch;

@torch.compile()
def f(x: any, y: any) -> any {
    if not torch.equal(x, y) {
        cleanup();
        raise ValueError("mismatch");
    }
    return torch.relu(x);
}

def cleanup { }
