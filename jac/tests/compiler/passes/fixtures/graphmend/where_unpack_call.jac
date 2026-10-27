"""Branch calls that pass unpacked arguments: a merged call would have to carry
the `**opts` and `*rest` operands, so predication must decline."""
import torch;

def sink(t: any, *rest: any, **opts: any) -> any {
    return t;
}

@torch.compile()
def keyed(x: any, y: any, opts: dict[str, any]) -> any {
    if (x.sum() > 0) {
        sink(x, **opts);
    } else {
        sink(y, **opts);
    }
    return x;
}

@torch.compile()
def starred(x: any, y: any, rest: list[any]) -> any {
    if (x.sum() > 0) {
        sink(x, *rest);
    } else {
        sink(y, *rest);
    }
    return x;
}
