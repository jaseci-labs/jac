"""A sibling helper module deliberately named like the stdlib json module.

Only the name collides: the module is ordinary user code holding a helper the
decorated entry reaches across the module boundary."""
import torch;

def near_helper(x: any) -> any {
    print('NEAR', x);
    return torch.relu(x);
}
