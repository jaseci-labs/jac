"""A print into a with-bound file would replay after the file closes, so it stays
eager."""
import torch;

@torch.compile()
def to_file(x: any, path: str) -> any {
    x = torch.relu(x);
    with open(path, "w") as fh {
        print("GM-FILE", file=fh);
    }
    return x * 2.0;
}
