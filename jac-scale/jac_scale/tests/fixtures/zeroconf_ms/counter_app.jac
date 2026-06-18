"""Counter service. `_app` suffix exercises derive_prefix stripping."""
glob _n: int = 0;

to sv:

def:pub bump -> dict {
    global _n;
    _n += 1;
    return {"count": _n};
}
