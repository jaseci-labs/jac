"""Soundness: one branch value is a CALL, the other a literal.

Neither rewrite is legal here. `torch.where` evaluates BOTH operands, so it
would run `side_effecting` on executions that take the else branch -- an
observable effect (the print) the original never performed. `torch.cond` is not
an option either: its branches must return tensors, not a Python float. So the
conditional must be left intact and the graph break kept."""
import torch;

def side_effecting(x: any) -> any {
    print("RAN");
    return x * 2;
}

@torch.compile()
def f(x: any) -> any {
    if (x.sum() > 0) {
        y = side_effecting(x);
    } else {
        y = 1.0;
    }
    return y;
}
