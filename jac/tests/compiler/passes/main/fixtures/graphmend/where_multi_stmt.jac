"""Literal paper Fig. 4 (Phi-4 longrope): multi-statement data-dependent
branches that share a trailing register_buffer call, with a nested *static*
hasattr guard that must be preserved and hoisted, not rewritten.

Mirrors the real `transformers/modeling_rope_utils.py`: the initializer is
reached through an attribute (`self_obj.rope_init_fn`) that is bound elsewhere
from a module-level dispatch table, so the hoist is licensed only because every
function in that table is checkably pure and non-raising (G5). The
`len(rope_kwargs) > 0` validation raise is the upstream idiom verbatim -- it is
unreachable here because the call passes no keyword outside the named
parameters."""
import torch;

def _compute_default_rope(config: any, device: any, **rope_kwargs: any) -> any {
    if len(rope_kwargs) > 0 {
        raise ValueError("Unexpected arguments: `**rope_kwargs` should be unset");
    }
    return torch.arange(0, 8).float().to(device);
}

def _compute_longrope(config: any, device: any, **rope_kwargs: any) -> any {
    if len(rope_kwargs) > 0 {
        raise ValueError("Unexpected arguments: `**rope_kwargs` should be unset");
    }
    return torch.arange(0, 16).float().to(device);
}

glob ROPE_INIT_FUNCTIONS = {
         "default": _compute_default_rope,
         "longrope": _compute_longrope
     };

@torch.compile()
def update(self_obj: any, position_ids: any, device: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if hasattr(self_obj.config, "original_max_position_embeddings") {
        omp = self_obj.config.original_max_position_embeddings;
    } else {
        omp = self_obj.config.max_position_embeddings;
    }
    if (seq_len > omp) {
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
