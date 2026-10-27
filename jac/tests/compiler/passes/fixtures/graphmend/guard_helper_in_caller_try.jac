"""A guard in a reached helper whose caller catches its exception: the lowered
assert would surface as RuntimeError past that handler, so the guard declines."""
import torch;

def check(x: any, mask: torch.Tensor) -> any {
    if not mask.all() {
        raise ValueError("mask must be all true");
    }
    return x;
}

@torch.compile()
def f(x: any, mask: torch.Tensor) -> any {
    x = torch.relu(x);
    try {
        x = check(x, mask);
    } except ValueError {
        x = x * 0.0;
    }
    return torch.sin(x);
}
