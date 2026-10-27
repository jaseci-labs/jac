"""Soundness: a well-formed existence-guarded init whose attribute is ALSO read
outside the rewritten region. Hoisting creates `long_inv_freq` on runs where the
original never would, and that other reader can observe the difference, so
GraphMend must DECLINE. Contrast with where_multi_stmt.jac, where the attribute
is confined to the region."""
import torch;

def peek(self_obj: any) -> any {
    return hasattr(self_obj, "long_inv_freq");
}

@torch.compile()
def f(self_obj: any, position_ids: any, device: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if (seq_len > 8) {
        if not hasattr(self_obj, "long_inv_freq") {
            self_obj.long_inv_freq = self_obj.rope_init_fn(self_obj.config, device);
        }
        self_obj.register_buffer("inv_freq", self_obj.long_inv_freq, persistent=False);
    } else {
        self_obj.original_inv_freq = self_obj.original_inv_freq.to(device);
        self_obj.register_buffer(
            "inv_freq", self_obj.original_inv_freq, persistent=False
        );
    }
    return self_obj.inv_freq;
}
