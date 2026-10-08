"""Soundness: a device move of an attribute the region never reads again.
The idempotent-move license exists so a value consumed by the merged call is
on the right device; a move whose target feeds nothing in the region is a
bare attribute mutation smuggled under the license and must DECLINE."""
import torch;

@torch.compile()
def f(self_obj: any, position_ids: any, device: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if (seq_len > 8) {
        self_obj.register_buffer("inv_freq", self_obj.long_inv_freq, persistent=False);
    } else {
        self_obj.scratch = self_obj.scratch.to(device);
        self_obj.register_buffer(
            "inv_freq", self_obj.original_inv_freq, persistent=False
        );
    }
    return self_obj.inv_freq;
}
