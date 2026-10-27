"""A torch.compile spelling on a parameter named torch: it is not the torch
module, so neither the trap boundary nor the defer hooks may wrap its result."""
import torch;

def build(torch: any, fn: any) -> any {
    model = torch.compile(fn);
    return model;
}
