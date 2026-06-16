"""A @torch.compile-decorated class (nn.Module-style) is an entry point, so a
data-dependent branch in its forward method must be tagged."""
import torch;

@torch.compile
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
