"""A receiver that is a non-tensor at the guard site and a tensor only later:
`m` holds a plain list when the guard reads it, and is rebound to a tensor
after the raise. `defining_assignment` resolves the textually LAST definition,
so a flow-insensitive proof would read the future and lower the guard against
a list. Multiple definitions make the binding flow-sensitive: refuse to prove."""
import torch;

def load_flags -> any {
    return [1, 1];
}

@torch.compile()
def f(x: any, mask: torch.Tensor) -> any {
    x = torch.relu(x);
    m = load_flags();
    if not m.all() {
        raise ValueError("flags must be all true");
    }
    m = mask;
    return torch.sin(x) * m;
}
