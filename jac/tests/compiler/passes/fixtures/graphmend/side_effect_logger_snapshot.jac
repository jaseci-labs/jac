"""A logger call in a forward followed by an in-place write to its argument: the
slot call must snapshot the argument at the call site, as a print does."""
import torch;
import logging;

glob logger = logging.getLogger("gm_snapshot");

class Net(torch.nn.Module) {
    def forward(self: any, x: any) -> any {
        y = torch.relu(x);
        logger.warning("snap %s", y);
        y.add_(100.0);
        return y;
    }
}
