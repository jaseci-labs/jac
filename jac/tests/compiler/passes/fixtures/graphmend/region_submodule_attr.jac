"""A submodule held in an attribute joins the region through the constructor.

`__init__` assigns `self.blk = Block()`, and that binding is what proves the
attribute's archetype, so `self.blk.project(...)` resolves to `Block.project`.
`self.opaque` is assigned a call the analysis cannot resolve to a class, so
`self.opaque.spare(...)` proves nothing and `spare` must stay untouched: the
edge is the constructor binding, never the attribute spelling."""
import torch;

class Block(torch.nn.Module) {
    def project(self: any, x: any) -> any {
        print("BLOCK-PROJECT", x);
        return x * 3.0;
    }

    def spare(self: any, x: any) -> any {
        print("BLOCK-SPARE", x);
        return x;
    }

    def forward(self: any, x: any) -> any {
        return x;
    }
}

def make_block -> any {
    return Block();
}

class Net(torch.nn.Module) {
    def __init__(self: Net) -> None {
        self.blk = Block();
        self.opaque = make_block();
    }

    def forward(self: any, x: any) -> any {
        y = self.blk.project(torch.relu(x));
        return self.opaque.spare(y);
    }
}
