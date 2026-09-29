"""Soundness: the same `.get` read, but `LooseConfig` never validates
`rope_scaling`, so nothing proves the receiver is a dict -- the same
expression shape covers a session object whose `.get` does I/O. Without the
constructor invariant the initializer is not speculatable and the rewrite
must DECLINE."""
import torch;

class LooseConfig {
    def __init__(self: LooseConfig, rope_scaling: any = None) -> None {
        self.rope_scaling = rope_scaling;
    }
}

def _compute_long(config: LooseConfig, device: any, **rope_kwargs: any) -> any {
    if len(rope_kwargs) > 0 {
        raise ValueError("Unexpected arguments: `**rope_kwargs` should be unset");
    }
    factor = config.rope_scaling.get("factor");
    return torch.arange(0, 8).float().to(device) * factor;
}

glob ROPE_INIT_FUNCTIONS = {"long": _compute_long};

@torch.compile()
def update(self_obj: any, config: LooseConfig, position_ids: any, device: any) -> any {
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
