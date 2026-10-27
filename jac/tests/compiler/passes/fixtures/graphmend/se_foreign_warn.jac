"""An attribute call matching the logging vocabulary on a receiver that does
not bind to a logger: deferring it would reorder arbitrary user code, so it
is not tagged."""
import torch;
import myutils;

@torch.compile()
def f(x: any) -> any {
    y = torch.relu(x);
    myutils.warn_user(y);
    return torch.sin(y);
}
