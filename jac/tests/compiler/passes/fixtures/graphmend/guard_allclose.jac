"""An allclose guard on a proven tensor: allclose returns a Python bool, which
torch._assert_async rejects, so the guard must decline."""
import torch;

@torch.compile()
def f(x: torch.Tensor, ref: torch.Tensor) -> any {
    if not x.allclose(ref) {
        raise ValueError("output drifted");
    }
    return torch.sin(x);
}
