"""Consumer analysis, negative case: another function
reads the moved attribute WITHOUT normalizing its device first, so it can
observe the placement change the hoisted move makes on executions that took
the other branch. Must DECLINE."""
import torch;

@torch.compile()
def f(self_obj: any, position_ids: any, device: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if (seq_len > 8) {
        self_obj.register_buffer("inv_freq", self_obj.long_inv_freq, persistent=False);
    } else {
        self_obj.original_inv_freq = self_obj.original_inv_freq.to(device);
        self_obj.register_buffer(
            "inv_freq", self_obj.original_inv_freq, persistent=False
        );
    }
    return self_obj.inv_freq;
}

def peek(self_obj: any) -> any {
    return self_obj.original_inv_freq * 2;
}
