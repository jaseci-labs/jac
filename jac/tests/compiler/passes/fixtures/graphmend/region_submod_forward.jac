"""A submodule attribute call dispatches to the held class's forward.

`Mixin.forward` is not a forward seed: `Mixin` has no Module base, and `Held`,
which has one, declares no forward of its own. It reaches the region only
because the constructor proves `self.blk` holds a `Held` and the base chain
proves that calling a Module dispatches to `Mixin.forward`. `mixin_orphan` sits
beside it and is reached by nothing."""
import torch;

class Mixin {
    def forward(self: any, x: any) -> any {
        print("MIXIN-FORWARD", x);
        return x * 2.0;
    }

    def mixin_orphan(self: any, x: any) -> any {
        print("MIXIN-ORPHAN", x);
        return x;
    }
}

class Held(torch.nn.Module, Mixin) {
    def tag(self: any) -> str {
        return "held";
    }
}

class Outer(torch.nn.Module) {
    def __init__(self: Outer) -> None {
        self.blk = Held();
    }

    def forward(self: any, x: any) -> any {
        return self.blk(torch.relu(x));
    }
}
