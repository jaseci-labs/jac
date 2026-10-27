"""An initializer whose only raise is guarded by an `and` holding a nonempty
varkw check, the transformers rope-init idiom: with no extra keyword passed the
raise is unreachable, so the hoist stays licensed."""
import torch;

def _compute_clean(config: any, device: any, **rope_kwargs: any) -> any {
    if config is not None and len(rope_kwargs) > 0 {
        raise ValueError("config and rope_kwargs are mutually exclusive");
    }
    return torch.arange(0, 8).float().to(device);
}

glob ROPE_INIT_FUNCTIONS = {"clean": _compute_clean};

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
