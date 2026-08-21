"""Soundness: the consumer's first TEXTUAL mention of the moved attribute is
a normalizing move, but it sits in a branch the reads do not share, so it
does not dominate them: an execution can skip the normalization and read the
placement the hoisted move installed. Must DECLINE."""
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

def peek(self_obj: any, flag: bool, device: any) -> any {
    if flag {
        self_obj.original_inv_freq = self_obj.original_inv_freq.to(device);
    }
    return self_obj.original_inv_freq;
}
