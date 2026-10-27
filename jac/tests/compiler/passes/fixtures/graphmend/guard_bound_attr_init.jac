"""An existence-guarded init whose attribute callee the module binds to a
function outside the dispatch table: the table's purity says nothing about
the bound callee, so the hoist must decline."""
import torch;

def _compute_clean(config: any, device: any, **rope_kwargs: any) -> any {
    return torch.arange(0, 8).float().to(device);
}

def _compute_dirty(config: any, device: any, **rope_kwargs: any) -> any {
    print("initializing");
    return torch.arange(0, 16).float().to(device);
}

glob ROPE_INIT_FUNCTIONS = {"clean": _compute_clean};

def bind(self_obj: any) {
    self_obj.rope_init_fn = _compute_dirty;
}

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
