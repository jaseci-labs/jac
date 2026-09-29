"""A call-site wrapped entry function with a helper one call away.

`wrapped` becomes an entry through `torch.compile(wrapped)` rather than a
decorator; its own print and the print in `wrap_helper`, reached through the
call edge, both belong to the compiled region."""
import torch;

def wrap_helper(x: any) -> any {
    print("WRAP-HELPER", x);
    return x * 2.0;
}

def wrapped(x: any) -> any {
    a = wrap_helper(x);
    print("WRAP-DIRECT", a);
    return torch.sin(a);
}

glob compiled_fn = torch.compile(wrapped);
