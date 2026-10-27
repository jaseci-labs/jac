"""Branch values whose subscripts differ can differ in shape, and torch.where
would broadcast the taken one, so predication must decline."""
import torch;

@torch.compile()
def first_row(x: torch.Tensor) -> any {
    if (x.sum() > 0) {
        return x[0];
    } else {
        return x;
    }
}

@torch.compile()
def last_row(h: torch.Tensor) -> any {
    if (h.sum() > 0) {
        y = h[-1];
    } else {
        y = h;
    }
    return y;
}
