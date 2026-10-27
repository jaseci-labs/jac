"""A guard in a helper reached from a compiled class has no boundary.

The archetype carries the decorator, no ability does, and there is no call-site
wrap, so nothing here can carry `__jac_trap_guard__` to decode a marker. Region
membership alone does not license the rewrite: the reached helper's guard must
decline exactly as the enclosing method's own guard does."""
import torch;

def unbounded_helper(x: any, mask: torch.Tensor) -> any {
    if not mask.all() {
        raise ValueError("unbounded mask must be all true");
    }
    return torch.sin(x);
}

@torch.compile()
class Unbounded(torch.nn.Module) {
    def forward(self: any, x: any, mask: torch.Tensor) -> any {
        return unbounded_helper(torch.relu(x), mask);
    }
}
