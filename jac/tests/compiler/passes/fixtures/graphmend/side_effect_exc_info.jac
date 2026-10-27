"""A logger call that reads the handled exception would replay after the except
block, recording no traceback, so it stays eager."""
import torch;
import logging;

glob logger = logging.getLogger("gm_exc_info");

@torch.compile()
def f(x: any) -> any {
    x = torch.relu(x);
    try {
        raise ValueError("boom");
    } except ValueError {
        logger.warning("GM-EXC", exc_info=True);
    }
    return x * 2.0;
}
