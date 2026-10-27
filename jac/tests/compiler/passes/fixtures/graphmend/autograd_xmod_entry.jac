"""Compiles the model from autograd_xmod_model.jac and runs backward through it."""
import torch;
import from autograd_xmod_model { Net }

def train(x: any) -> None {
    model: any = torch.compile(Net());
    model(x).sum().backward();
}
