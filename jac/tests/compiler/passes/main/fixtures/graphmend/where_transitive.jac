"""Transitive data-dependence: the condition compares a variable derived from a
dynamic torch op (torch.max), so it is tagged via the use-def trace rather than
a direct attribute match."""
import torch;

@torch.compile()
def f(x: any) -> any {
    seq_len = torch.max(x) + 1;
    if seq_len > 8 {
        y = x * 2;
    } else {
        y = x / 2;
    }
    return y;
}
