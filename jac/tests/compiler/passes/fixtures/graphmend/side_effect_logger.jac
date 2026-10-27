"""Logger side effect inside a compiled region (runnable: defines its logger)."""
import torch;
import logging;

glob log = logging.getLogger("graphmend_demo");

@torch.compile()
def f(x: any) -> any {
    x = torch.relu(x);
    log.warning("deprecated path");
    return torch.sin(x);
}
