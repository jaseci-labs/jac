"""Side effect with a dotted callee and a keyword argument: the kwarg is
preserved in the buffered entry's kwargs dict."""
import torch;

@torch.compile()
def f(x: any) -> any {
    logger.warning("deprecated", stacklevel=2);
    return torch.sin(x);
}
