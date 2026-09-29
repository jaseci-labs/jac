"""Soundness: both branches end in the same call, but the differing positional
arguments CONTAIN CALLS. `torch.where` evaluates both operands, so merging
would run the untaken branch's call -- an effect or exception the original
never produced. Must DECLINE and keep the break."""
import torch;

def loud(t: any) -> any {
    print("RAN");
    return t;
}

def quiet(t: any) -> any {
    return t * 2;
}

@torch.compile()
def f(self_obj: any, position_ids: any) -> any {
    seq_len = torch.max(position_ids) + 1;
    if (seq_len > 8) {
        self_obj.register_buffer("inv_freq", loud(self_obj.a), persistent=False);
    } else {
        self_obj.register_buffer("inv_freq", quiet(self_obj.b), persistent=False);
    }
    return self_obj.inv_freq;
}
