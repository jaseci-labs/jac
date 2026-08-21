"""Data-dependent guard inside a @torch.compile-decorated class.

Detection tags the guard because the enclosing archetype is an entry point, but
no enclosing ability carries the decorator, so there is no compiled call
boundary at which a trap guard could restore the exception -- and an async
assert can surface after the method has already returned. GraphMend declines."""
import torch;

@torch.compile()
class Model(torch.nn.Module) {
    def forward(self: any, x: any, mask: any) -> any {
        x = torch.relu(x);
        if not mask.all() {
            raise ValueError("mask must be all true");
        }
        return torch.sin(x) * 2.0;
    }
}
