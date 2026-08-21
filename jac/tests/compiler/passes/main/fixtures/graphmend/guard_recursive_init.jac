"""Soundness: the initializer reaches a pair of mutually recursive helpers.
Each body is individually clean, but termination for the speculated call is
unprovable, and a nonterminating speculation raises RecursionError on a path
the original never executed. A cycle in the helper call graph must DECLINE."""
import torch;

def _ping(n: any) -> any {
    return _pong(n);
}

def _pong(n: any) -> any {
    return _ping(n);
}

def _compute_long(config: any, device: any, **rope_kwargs: any) -> any {
    if len(rope_kwargs) > 0 {
        raise ValueError("Unexpected arguments: `**rope_kwargs` should be unset");
    }
    depth = _ping(4);
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
