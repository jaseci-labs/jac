"""Validation guard whose literal message contains backslash sequences and a
quote: the marker must re-escape the decoded message so the restored exception
matches the original byte for byte."""
import torch;

@torch.compile()
def f(x: any, mask: torch.Tensor) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("bad mask C:\\new \"q\"\tend");
    }
    return torch.sin(x) * 2.0;
}
