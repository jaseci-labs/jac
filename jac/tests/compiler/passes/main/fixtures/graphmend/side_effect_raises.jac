"""A compiled function that buffers a side effect and then RAISES.

[Defer] moves the print's emission to after the compiled region, so on this path
the in-function flush is never reached. Without a boundary that still drains the
buffer, the output would be silently lost -- the original program prints before
raising, the transformed one would not.

The `@__jac_se_guard__` decorator GraphMend prepends sits above `@torch.compile`,
so its `finally` is eager code outside the traced region and replays the buffered
call in FIFO order before the exception propagates."""
import torch;

@torch.compile()
def f(x: any) -> any {
    x = torch.relu(x);
    print("GM-SE-BEFORE-RAISE");
    raise ValueError("GM-SE-BOOM");
}
