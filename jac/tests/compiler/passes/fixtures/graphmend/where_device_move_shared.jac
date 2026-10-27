"""Consumer analysis, positive case: the moved attribute has a consumer in
another function, but that consumer's FIRST mention of the attribute is the
same normalizing device move, so it re-establishes device placement before
every read and cannot observe the hoisted move. This is the common shape of
shared rotary-embedding caches in model code. The hoist is licensed."""
import torch;

@torch.compile()
def f(self_obj: any, position_ids: any, device: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if (seq_len > 8) {
        self_obj.register_buffer("inv_freq", self_obj.long_inv_freq, persistent=False);
    } else {
        self_obj.original_inv_freq = self_obj.original_inv_freq.to(device);
        self_obj.register_buffer(
            "inv_freq", self_obj.original_inv_freq, persistent=False
        );
    }
    return self_obj.inv_freq;
}

def dynamic_update(self_obj: any, seq_len: int, device: any) -> any {
    if (seq_len < 8) {
        self_obj.original_inv_freq = self_obj.original_inv_freq.to(device);
        self_obj.register_buffer(
            "inv_freq", self_obj.original_inv_freq, persistent=False
        );
    }
    return self_obj.inv_freq;
}
