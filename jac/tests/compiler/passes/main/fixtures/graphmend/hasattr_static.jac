"""Static introspection control flow (hasattr on a non-tensor object param):
Dynamo handles this without a break, so GraphMend must NOT tag/rewrite it."""
import torch;

@torch.compile()
def f(self_obj: any, x: any) -> any {
    if hasattr(self_obj, "flag") {
        y = x + 1;
    } else {
        y = x + 2;
    }
    return y;
}
