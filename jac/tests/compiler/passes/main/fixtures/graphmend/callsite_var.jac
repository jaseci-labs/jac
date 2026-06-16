"""Entry point wrapped at a call site through a variable -- `torch.compile(m)`
where `m = Model()`. Exercises _resolve_wrapped_entry -> _var_assignment ->
_def_node, and tags the data-dependent branch inside the resolved class."""
import torch;

obj Model {
    def forward(x: any) -> any {
        if x.sum() > 0 {
            y = x * 2;
        } else {
            y = x / 2;
        }
        return y;
    }
}

glob m = Model();

with entry {
    torch.compile(m);
}
