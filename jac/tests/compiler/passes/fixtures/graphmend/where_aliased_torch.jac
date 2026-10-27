"""An aliased torch import leaves the bare name torch unbound where the rewrite
would emit torch.where, so predication must decline."""
import torch as t;

class Net(t.nn.Module) {
    def forward(self: any, x: any) -> any {
        if (x.sum() > 0) {
            y = x * 2.0;
        } else {
            y = x * 3.0;
        }
        return y;
    }
}
