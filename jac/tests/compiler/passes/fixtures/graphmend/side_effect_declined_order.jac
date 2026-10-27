"""A deferrable logger call in one function and one that must stay eager in
another: deferring the first would emit it after the second, so the module
keeps both eager."""
import torch;
import logging;

glob logger = logging.getLogger("gm_order");

@torch.compile()
def first(x: any) -> any {
    x = torch.relu(x);
    logger.warning("first");
    return x * 2.0;
}

@torch.compile()
def second(x: any) -> any {
    x = torch.relu(x);
    logger.warning("second", stack_info=True);
    return x * 3.0;
}
