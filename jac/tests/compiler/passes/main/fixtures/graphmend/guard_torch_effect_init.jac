"""Soundness: an existence-guarded init whose initializer calls an effectful
`torch` API. Being rooted at `torch` does not make a call pure: `torch.save`
writes a file, `torch.manual_seed` mutates global RNG state. Speculating the
init would perform that effect on runs the original never made, so only calls
on the checked pure-op list are speculatable and everything else declines."""
import torch;

def _compute_clean(config: any, device: any, **rope_kwargs: any) -> any {
    return torch.arange(0, 8).float().to(device);
}

def _compute_saving(config: any, device: any, **rope_kwargs: any) -> any {
    freqs = torch.arange(0, 16).float().to(device);
    torch.save(freqs, "inv_freq.pt");
    return freqs;
}

glob ROPE_INIT_FUNCTIONS = {"clean": _compute_clean, "saving": _compute_saving};

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
