"""Soundness: a branch setup writes a bare local that is live outside the
region. The write is call-free, but hoisting it publishes the taken branch's
value to code that runs on the untaken path too, so the write is not
observationally neutral. GraphMend must DECLINE."""
import torch;

@torch.compile()
def f(position_ids: any, x: any, y: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    scale = x * 0;
    if (seq_len > 8) {
        scale = x * 2;
        combine(scale, x, mode="a");
    } else {
        combine(scale, y, mode="a");
    }
    return scale;
}
