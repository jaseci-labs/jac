"""Data-dependent control flow where both branches make the same call with a
differing argument, the shared-trailing-call reconciliation shape."""
import torch;

@torch.compile()
def f(self_obj: any, position_ids: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if (seq_len > 8) {
        self_obj.register_buffer("inv_freq", self_obj.long_inv_freq, persistent=False);
    } else {
        self_obj.register_buffer(
            "inv_freq", self_obj.original_inv_freq, persistent=False
        );
    }
    return self_obj.inv_freq;
}
