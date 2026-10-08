"""Data-dependent guard whose message is a runtime expression.

A concatenation is not a string literal, so no trap marker can be built and the
boundary guard would have nothing to restore: the failure would surface as
RuntimeError instead of the original ValueError. GraphMend declines."""
import torch;

@torch.compile()
def f(x: any, mask: any, name: str) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("bad mask in " + name);
    }
    return torch.sin(x) * 2.0;
}
