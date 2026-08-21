"""A module with no torch import at all: data-dependent control flow and a
side-effect call that GraphMend would consider if it were engaged, so the
auto-mode tests can prove a torch-free module compiles byte-identical to a
graphmend-off compile."""
def classify(x: int) -> int {
    if x > 0 {
        print("positive");
        return x * 2;
    }
    return x * 3;
}
