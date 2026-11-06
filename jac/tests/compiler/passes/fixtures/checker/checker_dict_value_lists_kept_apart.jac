"""A dict literal's list values of different element types stay apart, so
a mistyped value is reported whichever key comes first."""

def take(samples: dict[str, list[float]]) -> int {
    return len(samples);
}

with entry {
    take({"probe": [60.0, 61.0], "ready": [1, "x", -2.0]});
    take({"ready": [1, "x", -2.0], "probe": [60.0, 61.0]});
    take({"probe": [60.0, 61.0], "ready": [1, 2.0]});
}
