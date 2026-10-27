"""Validation guard spelled as a comparison instead of `not C`. Real model code
writes the negation with an operator, so this shape lowers too: the assert takes
the negation of the whole condition, preserving the guard's truth value."""
import torch;

@torch.compile()
def f(x: any, mask: torch.Tensor) -> any {
    x = torch.relu(x);
    if mask.sum() != 4 {
        raise ValueError("mask must have four set entries");
    }
    return torch.sin(x) * 2.0;
}
