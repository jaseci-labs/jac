"""Logger method call (`logger.info(...)`) inside a compiled region: a
side-effect break detected by its method name, not a callee substring."""
import torch;
import from logging { getLogger }

glob log = getLogger("m");

@torch.compile()
def f(x: any) -> any {
    log.info("step");
    return torch.relu(x);
}
