"""Jac-authored mock for the `@fake/telemetry` npm package."""

glob:pub EVENTS: list = [];

def:pub track(name: str) -> str {
    EVENTS.append(name);
    return "tracked:" + name;
}

def:pub trackedCount -> int {
    return len(EVENTS);
}
