"""Logger break in an nn.Module forward that RAISES after the logger call.

[Defer] moves the logger call's emission to after the compiled region, so the
call is buffered rather than performed at its original site. If the forward then
raises, a plain forward hook never runs and the buffered log would be silently
dropped -- an observable behavior change (the original program prints, the
transformed one does not).

GraphMend registers the flush hook with ``always_call=True``, so the buffered
call is still replayed, in FIFO order, before the exception propagates.
"""

import logging

import torch

logger = logging.getLogger("gm_forward_hook_raises")


class Net(torch.nn.Module):
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = torch.relu(x)
        logger.warning("GM-RAISING-FORWARD-LOG")
        raise ValueError("GM-BOOM")


model = torch.compile(Net())
