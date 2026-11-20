"""A block-bodied lambda whose tail violates its return annotation must be diagnosed."""
def make_bad_key -> any {
    return lambda (w: str) -> (int, int) { (w, len(w)); };
}

with entry {
    print(make_bad_key()("ab")[1]);
}
