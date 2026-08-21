"""A decorated entry whose guarded helper lives in another module.

The boundary decorator can only be attached to a function in the module the
trap pass is rewriting, so this entry cannot cover the helper's guard: the
helper module compiles with its raise intact."""
import torch;
import from guard_xmod_helper { far_guard }

@torch.compile()
def xmod_entry(x: any, mask: torch.Tensor) -> any {
    return far_guard(torch.relu(x), mask);
}
