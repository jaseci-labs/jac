"""Soundness: an existence-guarded init whose initializer is NOT pure.

Same shape as where_multi_stmt.jac (the Phi-4 case), but one entry in the
dispatch table performs I/O. Hoisting runs the initializer on executions where
the original never would, so speculating a side-effecting callee would make that
effect happen on those runs. Since the attribute callee cannot be resolved to a
single table entry, EVERY signature-compatible candidate must be clean -- one
dirty entry must decline the whole rewrite."""
import torch;

def _compute_clean(config: any, device: any, **rope_kwargs: any) -> any {
    return torch.arange(0, 8).float().to(device);
}

def _compute_dirty(config: any, device: any, **rope_kwargs: any) -> any {
    print("initializing");
    return torch.arange(0, 16).float().to(device);
}

glob ROPE_INIT_FUNCTIONS = {"clean": _compute_clean, "dirty": _compute_dirty};

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
