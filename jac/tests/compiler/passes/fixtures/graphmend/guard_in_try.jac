"""Validation guard inside a lexical try: lowering would move the failure to
an async assert at the boundary, so the enclosing except would silently stop
firing; the guard must decline."""
import torch;

@torch.compile()
def f(x: any, mask: torch.Tensor) -> any {
    x = torch.relu(x);
    try {
        if not mask.all() {
            raise ValueError("mask must be all true");
        }
    } except ValueError {
        return x;
    }
    return torch.sin(x) * 2.0;
}
