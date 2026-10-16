"""Data-dependent guard whose message is an f-string.

The message cannot be folded into a compile-time trap marker (a MultiString's
literal value accumulates only its String parts, so the FString part would
vanish), and a runtime concat to rebuild it would itself break the graph.
Lowering anyway would raise the right exception type carrying an empty message,
so GraphMend declines and leaves the break in place."""
import torch;

@torch.compile()
def f(x: any, mask: any) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError(f"mask must be all true, got {mask.shape}");
    }
    return torch.sin(x) * 2.0;
}
