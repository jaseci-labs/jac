"""The guarded helper for the cross-module boundary decline.

`far_guard` is in the compiled region when the entry module is in the hub, and
its print does defer, but the only boundary its region offers is a decorator on
a function in another file: nothing in this module can carry it, so the guard
declines."""
import torch;

def far_guard(x: any, mask: torch.Tensor) -> any {
    if not mask.all() {
        raise ValueError("far mask must be all true");
    }
    print("FAR-GUARD", x);
    return torch.sin(x);
}
