"""Python side effect between tensor ops: print is buffered and flushed after
all compute, so the forward pass stays a single contiguous FX graph."""
import torch;

@torch.compile()
def f(x: any) -> any {
    x = torch.relu(x);
    print(x);
    return torch.sin(x) * 2.0;
}
