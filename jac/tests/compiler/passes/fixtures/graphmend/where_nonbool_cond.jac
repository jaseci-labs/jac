"""Conditions that are not a boolean tensor: a NumPy comparison spelled with
`.sum`, a float tensor used as the condition, a NumPy view of a tensor, and a
tensor method that returns a string. torch.where needs a boolean tensor
predicate, so predication must decline."""
import numpy as np;
import torch;

@torch.compile()
def numpy_sum(x: torch.Tensor, values: any) -> any {
    if np.sum(values) > 0 {
        return x * 2;
    } else {
        return x * 3;
    }
}

@torch.compile()
def float_cond(x: torch.Tensor) -> any {
    if x.sum() {
        return x * 2;
    } else {
        return x * 3;
    }
}

@torch.compile()
def numpy_view(x: torch.Tensor) -> any {
    if x.numpy().sum() > 0 {
        return x * 2;
    } else {
        return x * 3;
    }
}

@torch.compile()
def type_name(x: torch.Tensor) -> any {
    if x.type() == "torch.FloatTensor" {
        return x * 2;
    } else {
        return x * 3;
    }
}
