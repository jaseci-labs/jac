"""A comparison guard on a scalar method of a proven tensor: item() returns a
Python number, so the negated comparison is a Python bool and the guard must
decline."""
import torch;

@torch.compile()
def f(x: any, loss: torch.Tensor) -> any {
    x = torch.relu(x);
    if loss.item() > 100.0 {
        raise ValueError("loss diverged");
    }
    return torch.sin(x);
}
