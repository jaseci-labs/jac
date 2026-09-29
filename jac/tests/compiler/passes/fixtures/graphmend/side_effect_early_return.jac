"""Side effects with an early return: the buffer must be flushed before every
return so no deferred call is dropped."""
import torch;

@torch.compile()
def f(x: any, flag: bool) -> any {
    print("a");
    if flag {
        print("b");
        return x;
    }
    return torch.sin(x);
}
