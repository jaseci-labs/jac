"""Soundness: a data-dependent branch whose setup performs a non-idempotent,
observable write (incrementing an attribute counter) before the shared trailing
call. Hoisting that write to run on BOTH paths would change observable state, so
GraphMend must DECLINE -- the break is left intact rather than unsoundly
predicated. Contrast with where_multi_stmt.jac, whose setups are licensed
(existence-guarded init + idempotent device move)."""
import torch;

@torch.compile()
def f(self_obj: any, position_ids: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if (seq_len > 8) {
        self_obj.calls = self_obj.calls + 1;
        self_obj.register_buffer("inv_freq", self_obj.long_inv_freq, persistent=False);
    } else {
        self_obj.register_buffer(
            "inv_freq", self_obj.original_inv_freq, persistent=False
        );
    }
    return self_obj.inv_freq;
}
