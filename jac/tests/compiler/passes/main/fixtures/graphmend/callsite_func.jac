"""torch.compile(fn) on a bare function name compiles that function directly, so
its data-dependent branch must be tagged."""
import torch;

def fn(x: any) -> any {
    if x.sum() > 0 {
        y = x * 2;
    } else {
        y = x * 3;
    }
    return y;
}

with entry {
    torch.compile(fn);
}
