"""A logger call whose method name (`info`) collides with a module-level
function of the same name. The side-effect break must still be tagged: the
shadowing check applies to bare builtin calls, not attribute methods."""
import torch;
import from logging { getLogger }

glob log = getLogger("m");

@torch.compile()
def f(x: any) -> any {
    log.info("step");
    return torch.relu(x);
}

def info(msg: any) { }
