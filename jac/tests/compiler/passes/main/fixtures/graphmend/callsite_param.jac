"""torch.compile(model) where `model` is a function PARAMETER must NOT tag the
enclosing function's body -- only the model's forward (not the wrapper) is
compiled. The wrapper's data-dependent branch stays untagged."""
import torch;

def wrap(model: any, x: any) -> any {
    if x.sum() > 0 {
        y = x * 2;
    } else {
        y = x * 3;
    }
    compiled = torch.compile(model);
    return compiled(y);
}
