"""Soundness: tagged calls whose arguments arrive through an unpack.

The buffered entry rebuilds positionals as a tuple and keywords as a dict, so
`**opts` would be dropped and `*extra` cannot be hoisted into a temp at all.
Both DECLINE."""
import torch;
import logging;

glob logger = logging.getLogger("unpack_demo");

@torch.compile()
def star(x: any, extra: list) -> any {
    print("head", *extra);
    return torch.sin(x);
}

@torch.compile()
def double_star(x: any, opts: dict) -> any {
    logger.warning("deprecated", **opts);
    return torch.sin(x);
}
