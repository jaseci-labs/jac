"""A model with no autograd spelling of its own, compiled and trained from
autograd_xmod_entry.jac."""
import torch;

class Net(torch.nn.Module) {
    def forward(self: any, x: torch.Tensor) -> any {
        if (x.sum() == 0) {
            y = x * 2.0;
        } else {
            y = 1.0 / x;
        }
        return y;
    }
}
