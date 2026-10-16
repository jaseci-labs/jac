"""A decorated entry reaching a helper two call edges away.

`entry` calls `mid`, which calls `deep`; only `deep` carries a transformable
pattern. The compiled region must close over the whole chain, so the print in
`deep` is deferred exactly as if it sat in the entry itself."""
import torch;

def deep(x: any) -> any {
    print("DEEP-EFFECT", x);
    return x * 3.0;
}

def mid(x: any) -> any {
    y = torch.relu(x);
    return deep(y);
}

@torch.compile()
def `entry(x: any) -> any {
    return torch.sin(mid(x));
}
