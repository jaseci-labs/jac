"""Soundness: the initializer's `torch.arange` goes through a shadowed root.
`import fake as torch` binds the name to another library, so the allowlisted
leaf proves nothing; the binding is the proof, and a root that does not
declare at a genuine `import torch` must DECLINE."""
import fake as torch;

def _compute_long(config: any, device: any, **rope_kwargs: any) -> any {
    if len(rope_kwargs) > 0 {
        raise ValueError("Unexpected arguments: `**rope_kwargs` should be unset");
    }
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
