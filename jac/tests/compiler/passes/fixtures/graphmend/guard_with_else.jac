"""A guard with an else branch: replacing the if would drop the else body, so the
guard must decline."""
import torch;

@torch.compile()
def f(x: any, mask: torch.Tensor) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("mask must be all true");
    } else {
        x = x * 2.0;
    }
    return torch.sin(x);
}
