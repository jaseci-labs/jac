"""Side effect whose buffered tensor arg is mutated in place AFTER the call.

The deferred print must observe the value at the original call site, not the
post-mutation value, so GraphMend clones the arg when buffering it (paper Table
1, clone(args))."""
import torch;

@torch.compile()
def f(x: any) -> any {
    y = torch.relu(x);
    print("snap:", y);
    y.add_(100.0);
    return y;
}
