"""An f-string argument beside a call argument: both must be evaluated once, in
their original order, before the call is buffered."""
import torch;

@torch.compile()
def f(x: any, q: any) -> any {
    x = torch.relu(x);
    print(f"{q.pop()}", q.pop());
    return x * 2.0;
}
