"""The yarn-shaped initializer: a helper whose sub-helper is called twice
(once under floor, once under ceil), and whose result flows through a pure
tensor method on a local call's return value. A revisit of a helper already
proven on this walk is a diamond, not a cycle, and must stay licensed; only
a helper still on the recursion stack declines."""
import math;
import torch;

def _corr_dim(rot: any, dim: int, base: float) -> any {
    return dim * math.log(rot) / (2 * math.log(base));
}

def _corr_range(low_rot: any, high_rot: any, dim: int, base: float) -> any {
    low = math.floor(_corr_dim(low_rot, dim, base));
    high = math.ceil(_corr_dim(high_rot, dim, base));
    return max(low, 0);
}

def _ramp(low: any, dim: int) -> any {
    return torch.arange(0, dim).float() * low;
}

def _compute_long(config: any, device: any, **rope_kwargs: any) -> any {
    if len(rope_kwargs) > 0 {
        raise ValueError("Unexpected arguments: `**rope_kwargs` should be unset");
    }
    low = _corr_range(1.0, 2.0, 8, 10000.0);
    return _ramp(low, 8).to(device);
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
