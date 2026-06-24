"""A @torch.compile-decorated nn.Module subclass is an entry point, so a
data-dependent branch in its forward method must be tagged."""
import torch;
import from torch { nn }

@torch.compile
obj Model(nn.Module) {
    def forward(x: any) -> any {
        if x.sum() > 0 {
            y = x * 2;
        } else {
            y = x * 3;
        }
        return y;
    }
}
