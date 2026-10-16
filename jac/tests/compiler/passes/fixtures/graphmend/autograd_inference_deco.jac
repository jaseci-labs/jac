"""Transform: a no-arg inference_mode decorator proves the whole body runs
outside gradient tracking, even though the module trains elsewhere."""
import torch;

@torch.compile()
@torch.inference_mode()
def f(x: any, y: any) -> any {
    if (x.sum() > 0) {
        z = x + y;
    } else {
        z = x * y;
    }
    return z;
}

def run_epoch(loss: any) {
    loss.backward();
}
