"""The entry module for the cross-module compiled-region tests.

The decorated entry calls a helper imported from region_xmod_helper.jac; the
call edge crosses the module boundary, so the helper module's compile must see
this entry in the hub to place `far_helper` inside the compiled region."""
import torch;
import from region_xmod_helper { far_helper }

@torch.compile()
def `entry(x: any) -> any {
    return torch.sin(far_helper(x));
}
