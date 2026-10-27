"""A guard in a helper two compiled entries reach: the restoring boundary goes on
one entry only, so the other would surface a RuntimeError and the guard declines."""
import torch;

def check(x: any, mask: torch.Tensor) -> any {
    if not mask.all() {
        raise ValueError("mask must be all true");
    }
    return x;
}

@torch.compile()
def f(x: any, mask: torch.Tensor) -> any {
    return torch.sin(check(torch.relu(x), mask));
}

@torch.compile()
def g(x: any, mask: torch.Tensor) -> any {
    return torch.cos(check(torch.relu(x), mask));
}
