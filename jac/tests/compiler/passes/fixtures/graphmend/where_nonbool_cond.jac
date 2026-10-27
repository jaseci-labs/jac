"""Conditions that are not a boolean tensor: a NumPy comparison spelled with
`.sum`, and a float tensor used as the condition. torch.where needs a boolean
tensor predicate, so predication must decline."""
import numpy as np;
import torch;

@torch.compile()
def numpy_sum(x: any, values: any) -> any {
    if np.sum(values) > 0 {
        return x * 2;
    } else {
        return x * 3;
    }
}

@torch.compile()
def float_cond(x: any) -> any {
    if x.sum() {
        return x * 2;
    } else {
        return x * 3;
    }
}
