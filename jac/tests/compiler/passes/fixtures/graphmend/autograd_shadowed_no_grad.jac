"""Decline: a local rebinding shadows the torch root, so its no_grad() proves
nothing; the permit needs a name that declares at a genuine `import torch`."""
import torch;

def _stub -> any {
    return 0;
}

@torch.compile()
def f(x: any, y: any) -> any {
    torch = _stub();
    with torch.no_grad() {
        if (x.sum() > 0) {
            z = x + y;
        } else {
            z = x * y;
        }
    }
    return z;
}

def run_epoch(loss: any) {
    loss.backward();
}
