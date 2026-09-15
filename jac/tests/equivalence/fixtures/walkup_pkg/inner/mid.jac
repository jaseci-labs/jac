import from .leaf { leaf_tag }

def:pub mid_tag(n: int) -> str {
    return "mid(" + leaf_tag(n) + ")";
}
