import torch;

def with_breaks(a: Any, b: Any) {
    x = a / (torch.abs(a) + 1);
    b = b * 1.414;
    if (b.sum() < 0) {
        return x * (b * -1);
    } else {
        return x * (b * -2);
    }
}
