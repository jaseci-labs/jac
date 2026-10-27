"""A module that reaches the Module base through `from torch import nn` never
binds torch, so predication must decline."""
import from torch { nn }

class Net(nn.Module) {
    def forward(self: any, x: any) -> any {
        if (x.sum() > 0) {
            y = x * 2.0;
        } else {
            y = x * 3.0;
        }
        return y;
    }
}
