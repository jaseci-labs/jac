"""Decline: importing torch's autograd submodule puts autograd in play."""
import torch;
import from torch { autograd }

@torch.compile()
def f(x: any, y: any) -> any {
    if (x.sum() > 0) {
        z = x + y;
    } else {
        z = x * y;
    }
    return z;
}

def cfg {
    autograd.set_detect_anomaly(True);
}
