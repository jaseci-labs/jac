"""Decline: the innermost context wins; enable_grad re-enables tracking
inside the no_grad block, so the branch is back under autograd."""
import torch;

@torch.compile()
def f(x: any, y: any) -> any {
    with torch.no_grad() {
        with torch.enable_grad() {
            if (x.sum() > 0) {
                z = x + y;
            } else {
                z = x * y;
            }
        }
    }
    return z;
}
