"""Guards in helpers the compiled entry reaches lower at the entry's boundary.

`guarded_entry` carries the decorator, so `__jac_trap_guard__` can be attached
above it to decode the marker, and both helpers are in its compiled region. One
helper is declared before the entry and one after, because the boundary
decorator lands on a function the traversal may already have left behind."""
import torch;

def early_helper(x: any, mask: torch.Tensor) -> any {
    if not mask.all() {
        raise ValueError("early mask must be all true");
    }
    return torch.sin(x);
}

@torch.compile()
def guarded_entry(x: any, mask: torch.Tensor) -> any {
    return late_helper(early_helper(torch.relu(x), mask), mask);
}

def late_helper(x: any, mask: torch.Tensor) -> any {
    if not mask.all() {
        raise ValueError("late mask must be all true");
    }
    return torch.cos(x);
}
