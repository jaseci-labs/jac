"""A reassigned compile target resolves to its last assignment: the entry is
`Model` (not the earlier `Other`), so Model's data-dependent branch is tagged.
The reassignment lives in `sym.uses`, not `sym.defn`, so both must be scanned."""
import torch;

obj Other {
    def forward(x: any) -> any {
        return x;
    }
}

obj Model {
    def forward(x: any) -> any {
        if x.sum() > 0 {
            y = x * 2;
        } else {
            y = x * 3;
        }
        return y;
    }
}

glob m = Other(),
     m = Model();

with entry {
    torch.compile(m);
}
