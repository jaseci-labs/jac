"""Cross-module constructor invariant: the config class lives in a sibling
module, so proving `config.rope_scaling.get(...)` requires following the
import and materializing that module's AST into the hub on demand. Same
proof as guard_config_get, one module away."""
import torch;
import from rope_config_mod { RopeConfig }

def _compute_long(config: RopeConfig, device: any, **rope_kwargs: any) -> any {
    if len(rope_kwargs) > 0 {
        raise ValueError("Unexpected arguments: `**rope_kwargs` should be unset");
    }
    factor = config.rope_scaling.get("factor");  # jac:ignore[E1099]
    return torch.arange(0, 8).float().to(device) * factor;
}

glob ROPE_INIT_FUNCTIONS = {"long": _compute_long};

@torch.compile()
def update(self_obj: any, config: RopeConfig, position_ids: any, device: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if (seq_len > 8) {
        if not hasattr(self_obj, "long_inv_freq") {
            self_obj.long_inv_freq = self_obj.rope_init_fn(config, device);
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
