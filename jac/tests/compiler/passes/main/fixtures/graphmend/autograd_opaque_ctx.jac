"""Decline: an unrecognized context sits between the branch and no_grad; it
could restore gradient mode on entry, so the proof fails closed."""
import torch;

@torch.compile()
def f(x: any, y: any) -> any {
    with torch.no_grad() {
        with torch.autocast('cpu') {
            if (x.sum() > 0) {
                z = x + y;
            } else {
                z = x * y;
            }
        }
    }
    return z;
}

def run_epoch(loss: any) {
    loss.backward();
}
