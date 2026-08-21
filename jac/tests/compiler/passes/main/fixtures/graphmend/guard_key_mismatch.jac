"""Soundness: a non-idempotent observable write (`self.counter += 1`) smuggled
into a branch under a `hasattr` header whose key is NOT the attribute the body
assigns. The guard never closes, so the body re-runs on every call -- and
hoisting it would run the increment on the untaken path too. Recognizing the
`hasattr` *shape* alone would license this; GraphMend must DECLINE."""
import torch;

@torch.compile()
def f(self_obj: any, position_ids: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if (seq_len > 8) {
        if not hasattr(self_obj, "never_set") {
            self_obj.counter = self_obj.counter + 1;
            self_obj.long_inv_freq = self_obj.rope_init_fn(self_obj.config);
        }
        self_obj.register_buffer("inv_freq", self_obj.long_inv_freq, persistent=False);
    } else {
        self_obj.original_inv_freq = self_obj.original_inv_freq.to("cpu");
        self_obj.register_buffer(
            "inv_freq", self_obj.original_inv_freq, persistent=False
        );
    }
    return self_obj.inv_freq;
}
