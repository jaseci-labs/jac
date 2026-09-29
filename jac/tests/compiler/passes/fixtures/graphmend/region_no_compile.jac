"""A torch-importing module with no torch.compile usage anywhere.

Auto mode engages GraphMend on this module because it imports torch, but with
no entry point every function is outside the compiled region: the module must
compile byte-identical to a graphmend-off run even though each function holds
a transformable pattern."""
import torch;

def guard_fn(x: any, mask: torch.Tensor) -> any {
    if not mask.all() {
        raise ValueError("mask must be all true");
    }
    return torch.sin(x);
}

def branch_fn(x: any) -> any {
    if x.sum() > 0 {
        return x * 2.0;
    } else {
        return x * 3.0;
    }
}

def noisy_fn(x: any) -> any {
    print("NOISY", x);
    return torch.relu(x);
}
