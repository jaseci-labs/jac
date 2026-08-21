"""A non-literal keyword value must be snapshotted like a positional one, so
a later in-place mutation cannot change what the deferred call replays."""
import torch;
import logging;

glob logger = logging.getLogger("kwarg_snap");

@torch.compile()
def f(x: any) -> any {
    y = torch.relu(x);
    logger.warning("snap", extra=y);
    return torch.sin(y);
}
