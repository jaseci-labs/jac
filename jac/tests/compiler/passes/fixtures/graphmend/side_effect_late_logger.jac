"""A logger bound after the class whose forward uses it: a slot registration
placed after the class would read the logger before it exists, so the call
stays eager."""
import torch;
import logging;

class Net(torch.nn.Module) {
    def forward(self: any, x: any) -> any {
        x = torch.relu(x);
        logger.warning("GM-LATE");
        return x * 2.0;
    }
}

glob logger = logging.getLogger("gm_late");
