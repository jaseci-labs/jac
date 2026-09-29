"""An inherited method joins the region through the base chain.

`Net.forward` seeds on the Module base it reaches through `Base`, and calls
`self.helper(...)`, which is declared on `Base` only: resolving the self-call
through the base chain is the only edge that can place `helper` in the region.
`base_orphan` is declared beside it and called by nothing, so it must stay
untouched."""
import torch;

class Base(torch.nn.Module) {
    def helper(self: any, x: any) -> any {
        print("BASE-HELPER", x);
        return x + 1.0;
    }

    def base_orphan(self: any, x: any) -> any {
        print("BASE-ORPHAN", x);
        return x;
    }
}

class Net(Base) {
    def forward(self: any, x: any) -> any {
        return self.helper(torch.relu(x));
    }
}
