"""A `raise` inside an `elif` is NOT a standalone validation guard: the raise is
conditional on the leading `if` being false, so it must not be tagged val_guard
(an assert would fire unconditionally) nor dyn_ctrl_fl (the predicate rewrite
would drop the raise). The elif is left untagged -- a correct, unoptimized
break."""
import torch;

@torch.compile()
def f(flag: any, x: any) -> any {
    y = x;
    if hasattr(flag, "skip") {
        y = x * 2;
    } elif x.sum() > 0 {
        raise ValueError("positive");
    }
    return y;
}
