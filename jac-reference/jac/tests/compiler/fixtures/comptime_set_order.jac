"""Fixture: a comptime set whose element order must not reach the bytecode."""

import from jaclang.comptime { fields }

obj Sample {
    has walker_or_function: str = "",
        trigger: str = "",
        interval: str = "",
        cron: str = "",
        date: str = "";
}

def allowed_names -> set[str] {
    comptime names: set[str] = {f.name for f in fields(Sample)};
    return names;
}
