"""torch.compile's `model` argument may be passed by keyword
(`torch.compile(model=Model())`); the wrapped class is still an entry point, so
its data-dependent branch must be tagged."""
import torch;

obj Model {
    def forward(x: any) -> any {
        if x.sum() > 0 {
            y = x * 2;
        } else {
            y = x * 3;
        }
        return y;
    }
}

with entry {
    torch.compile(model=Model());
}
