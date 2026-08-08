"""nn.Module logger break, fixed via the forward-hook flush mechanism.

The logger call is inside `forward` (a traced region) and the model is wrapped
at a call site (`model = torch.compile(Net())`). GraphMend rewrites the logger
call to a slot-buffered emit and injects `model.register_forward_hook(...)` so
the buffered call is replayed in eager after the graph -- preserving the log
with zero graph break.
"""

import logging

import torch

logger = logging.getLogger("gm_forward_hook")


class Net(torch.nn.Module):
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = torch.relu(x)
        logger.warning("GM-FORWARD-HOOK-LOG")
        return torch.sin(x) * 2.0


model = torch.compile(Net())
