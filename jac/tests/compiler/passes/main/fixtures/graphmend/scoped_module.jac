"""Plain model code with no local torch.compile entry point. Detection applies
only under --graphmend-scope (whole-module mode); otherwise nothing is tagged."""
import torch;

def forward(x: any) -> any {
    if x.sum() > 0 {
        return x * 2;
    } else {
        return x / 2;
    }
}
