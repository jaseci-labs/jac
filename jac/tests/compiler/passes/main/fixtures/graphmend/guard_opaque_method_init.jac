"""Soundness: an existence-guarded init whose initializer calls a method named
like a pure tensor method (`clone`) on an opaque receiver.

`to`, `float`, `clone` and friends are only no-ops on a tensor; on an
arbitrary object the same leaf name can do anything, so matching the name
alone would speculate unknown work onto the untaken path. Purity is granted
only when the receiver is itself a pure call, as in
`torch.arange(...).float().to(device)`. Must DECLINE."""
import torch;

def _compute_clean(config: any, device: any, **rope_kwargs: any) -> any {
    return torch.arange(0, 8).float().to(device);
}

def _compute_from_store(config: any, device: any, **rope_kwargs: any) -> any {
    return config.store.clone().to(device);
}

glob ROPE_INIT_FUNCTIONS = {"clean": _compute_clean, "store": _compute_from_store};

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
