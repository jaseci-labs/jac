"""Soundness: both branches' setups write the same bare local before the
shared trailing call. Each write is call-free and confined to the region, so
neither is observable on its own -- but hoisting runs both unconditionally,
the second overwrites the first, and the merged call then reads the untaken
branch's value. GraphMend must DECLINE."""
import torch;

@torch.compile()
def f(position_ids: any, x: any, y: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if (seq_len > 8) {
        scale = x * 2;
        combine(scale, x, mode="a");
    } else {
        scale = y * 3;
        combine(scale, y, mode="a");
    }
    return x;
}
