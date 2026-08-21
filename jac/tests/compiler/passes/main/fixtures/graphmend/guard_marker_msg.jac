"""Validation guard whose literal message contains the trap close delimiter:
embedding it verbatim would make the boundary parse stop at the embedded
delimiter and truncate the restored message, so the trap pass must decline."""
import torch;

@torch.compile()
def f(x: any, mask: any) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("bad [[/GM-TRAP]] mask");
    }
    return torch.sin(x) * 2.0;
}
