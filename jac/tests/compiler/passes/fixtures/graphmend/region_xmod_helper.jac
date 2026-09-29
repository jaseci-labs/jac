"""Cross-module helpers for the compiled-region reachability tests.

`far_helper` is called by the decorated entry in region_xmod_entry.jac, so it
joins the compiled region when that entry's module is in the hub. `far_orphan`
is called by nothing and must stay untouched."""
import torch;

def far_helper(x: any) -> any {
    print("FAR-HELPER", x);
    return torch.relu(x);
}

def far_orphan(x: any) -> any {
    print("FAR-ORPHAN", x);
    return x;
}
