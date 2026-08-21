"""Precision: a user-defined helper whose name matches a logging pattern
(`warn`) must NOT be tagged as a side-effect break. The name resolves to a
local symbol, so deferring it would postpone arbitrary user compute, not a
logging call."""
import torch;

def warn_and_scale(x: any) -> any {
    return x * 2;
}

@torch.compile()
def f(x: any) -> any {
    y = warn_and_scale(x);
    return torch.sin(y);
}
