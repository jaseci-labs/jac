"""Soundness: the initializer calls `len`, but the module shadows the builtin
with an effectful definition. The spelling matches the pure-builtin list; the
binding proves it is not the builtin. Speculating it would print on the
untaken path, so the hoist must DECLINE."""
import torch;

def len(x: any) -> int {
    print("SHADOWED");
    return 0;
}

def _compute_long(config: any, device: any, **rope_kwargs: any) -> any {
    n = len(rope_kwargs);
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
