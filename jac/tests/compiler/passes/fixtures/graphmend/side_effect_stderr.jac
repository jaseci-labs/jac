"""A print to sys.stderr is buffered like a print to stdout."""
import sys;
import torch;

@torch.compile()
def to_stderr(x: any) -> any {
    x = torch.relu(x);
    print("GM-ERR", file=sys.stderr);
    return x * 2.0;
}
