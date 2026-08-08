"""Validation guard between tensor ops (torch.equal check then raise)."""
import torch;

@torch.compile()
def f(attention_mask: any, expected: any) -> any {
    x = torch.relu(attention_mask);
    if not torch.equal(attention_mask, expected) {
        raise ValueError("unsupported attention mask");
    }
    return torch.sin(x) * 2.0;
}
