"""Cross-function deferral: the print lives in a HELPER, not in the entry.

Dynamo inlines `helper` into `f`'s graph, so a flush at the helper's return
would split that graph from the inside. The helper therefore emits no flush at
all: the effect is buffered while the enclosing region is open and drained by
`f`'s boundary guard, which is what lets deferral reach the end of the whole
compiled computation rather than the end of the inner function."""
import torch;

def helper(x: any) -> any {
    y = torch.relu(x);
    print("FROM-HELPER", y);
    return y * 2.0;
}

@torch.compile()
def f(x: any) -> any {
    a = helper(x);
    return torch.sin(a);
}
