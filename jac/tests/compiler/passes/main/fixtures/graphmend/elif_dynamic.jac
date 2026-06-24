"""A data-dependent condition in an `elif` must be tagged even when the leading
`if` is static: the elif `x.sum() > 0` is the graph break, not the hasattr."""
import torch;

@torch.compile()
def f(self_obj: any, x: any) -> any {
    if hasattr(self_obj, "flag") {
        y = x * 2;
    } elif x.sum() > 0 {
        y = x * 3;
    } else {
        y = x * 4;
    }
    return y;
}
