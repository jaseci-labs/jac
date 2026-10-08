"""Transform: the branch sits inside torch.no_grad(), so even though the
module trains elsewhere, the region is provably outside gradient tracking."""
import torch;

@torch.compile()
def f(x: any, y: any) -> any {
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
