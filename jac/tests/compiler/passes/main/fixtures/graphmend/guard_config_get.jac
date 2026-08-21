"""A provable configuration read: the initializer calls
`config.rope_scaling.get("factor")`, which no purity list covers -- but the
`RopeConfig` constructor raises unless `rope_scaling` is a dict (or None, the
validate-in-the-constructor idiom, here inlined), so the fact pass proves the
receiver and `.get` is `dict.get`, a pure read. The hoist is licensed and the
branch predicates."""
import torch;

class RopeConfig {
    def __init__(self: RopeConfig, rope_scaling: (dict | None) = None) -> None {
        self.rope_scaling = rope_scaling;
        if self.rope_scaling is None {
            return;
        }
        if not isinstance(self.rope_scaling, dict) or (len(self.rope_scaling) != 3) {
            raise ValueError("rope_scaling must be a dict of len 3");
        }
    }
}

def _compute_long(config: RopeConfig, device: any, **rope_kwargs: any) -> any {
    if len(rope_kwargs) > 0 {
        raise ValueError("Unexpected arguments: `**rope_kwargs` should be unset");
    }
    factor = config.rope_scaling.get("factor");
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
