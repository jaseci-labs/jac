"""Soundness: the initializer helper raises nothing and calls only pure ops,
but it DELETES an attribute (`config.cache`). A delete is a write, and
speculating it would drop state on executions where the original never
entered the branch: DECLINE."""
import torch;

def _compute_long(config: any, device: any, **rope_kwargs: any) -> any {
    if len(rope_kwargs) > 0 {
        raise ValueError("Unexpected arguments: `**rope_kwargs` should be unset");
    }
    del config.cache;
    return torch.arange(0, 8).float().to(device);
}

glob ROPE_INIT_FUNCTIONS = {"long": _compute_long};

@torch.compile()
def update(self_obj: any, position_ids: any, device: any) -> any {
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
