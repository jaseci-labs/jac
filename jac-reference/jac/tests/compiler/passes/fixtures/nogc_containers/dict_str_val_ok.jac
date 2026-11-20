"""Move/copy-in: str keys and values enter an owned dict."""
def run -> int {
    d = {"a": f"v{1}"};
    d["b"] = f"v{2}";
    d[f"k{3}"] = "w";
    return len(d);
}

with entry {
    print(run());
}
