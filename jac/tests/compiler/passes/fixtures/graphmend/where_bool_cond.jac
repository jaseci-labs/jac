"""Conditions Python can evaluate to a bool rather than a tensor: a boolean
operator, a negation, a chained comparison, a name bound to a boolean
operator, and a builtin returning a Python value. torch.where needs a tensor
predicate, so predication must decline."""
import torch;

@torch.compile()
def flag_gate(x: torch.Tensor, flag: bool) -> any {
    if flag and (x.sum() > 0) {
        return x * 2;
    } else {
        return x * 3;
    }
}

@torch.compile()
def negated(x: torch.Tensor) -> any {
    if not (x.sum() > 0) {
        return x * 2;
    } else {
        return x * 3;
    }
}

@torch.compile()
def chained(x: torch.Tensor) -> any {
    if 0 < x.sum() < 5 {
        return x * 2;
    } else {
        return x * 3;
    }
}

@torch.compile()
def traced_flag(x: torch.Tensor, flag: bool) -> any {
    ok = flag and (x.sum() > 0);
    if ok {
        return x * 2;
    } else {
        return x * 3;
    }
}

@torch.compile()
def builtin_bool(x: torch.Tensor) -> any {
    if bool(x.sum() > 0) {
        return x * 2;
    } else {
        return x * 3;
    }
}
