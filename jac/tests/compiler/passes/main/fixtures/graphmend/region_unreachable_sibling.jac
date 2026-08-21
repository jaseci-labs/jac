"""A torch.compile entry beside an unreachable sibling subgraph.

`entry` is the only torch.compile entry point in the module. `orphan` carries
every transformable pattern (a lowerable tensor guard, a data-dependent
if/else, a print call) and `orphan_leaf` is called only by `orphan`: neither
is reachable from the entry, so GraphMend must leave both byte-identical."""
import torch;

@torch.compile()
def `entry(x: any, mask: torch.Tensor) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("entry mask must be all true");
    }
    print("ENTRY-EFFECT", x);
    return torch.sin(x);
}

def orphan(x: any, mask: torch.Tensor) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("orphan mask must be all true");
    }
    if x.sum() > 0 {
        y = x * 2.0;
    } else {
        y = x * 3.0;
    }
    print("ORPHAN-EFFECT", y);
    return orphan_leaf(y);
}

def orphan_leaf(x: any) -> any {
    print("ORPHAN-LEAF", x);
    return x;
}
