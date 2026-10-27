"""Static validation guard (no tensor-data dependence): Dynamo handles the
isinstance check without a break, so GraphMend must NOT rewrite it."""
import torch;

@torch.compile()
def f(x: any, flag: any) -> any {
    if not isinstance(flag, str) {
        raise TypeError("flag must be a string");
    }
    return torch.relu(x);
}
