"""Gateway entry. sv-imports a service; itself never a service."""
sv import from greeter { greet }

to sv:

def:pub hello -> dict {
    return greet("world");
}
