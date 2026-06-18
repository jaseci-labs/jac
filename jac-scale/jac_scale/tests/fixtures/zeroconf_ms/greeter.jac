"""Greeter service (no config block - discovered by `to sv:`)."""
to sv:

def:pub greet(name: str) -> dict {
    return {"msg": f"Hello, {name}!"};
}
