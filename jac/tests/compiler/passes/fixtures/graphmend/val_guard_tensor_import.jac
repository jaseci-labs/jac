"""A bare `Tensor` annotation bound by `from torch import Tensor`: the
binding, not the spelling, proves the receiver, so the guard lowers to a
direct graph-native assert."""
import torch;
import from torch { Tensor }

@torch.compile()
def f(x: any, mask: Tensor) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("mask must be all true");
    }
    return torch.sin(x) * 2.0;
}
