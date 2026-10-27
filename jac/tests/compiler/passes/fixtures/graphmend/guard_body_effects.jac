"""Soundness: an existence-guarded init whose body carries observable effects
beyond the memoizing write (console output, a list mutation). Even though the
guard key matches the memoized attribute, those effects would fire on runs where
the original program never entered the branch, so GraphMend must DECLINE."""
import torch;

@torch.compile()
def f(self_obj: any, position_ids: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if (seq_len > 8) {
        if not hasattr(self_obj, "cache") {
            self_obj.log.append("init");
            self_obj.cache = self_obj.build();
        }
        self_obj.register_buffer("inv_freq", self_obj.cache, persistent=False);
    } else {
        self_obj.register_buffer(
            "inv_freq", self_obj.original_inv_freq, persistent=False
        );
    }
    return self_obj.inv_freq;
}
