"""Locals named like a decorated and a generic function of an imported module.

Only `plain` is imported. A decorated function is called through a slot and a
generic one is instantiated per call, each on its own path through the call
lowering; a local of either name is still the local.
"""
import from var_shadows_function_kinds_lib { plain }

def decorated_name_probe -> int {
    glint = lambda (x: int) -> int { return x + 200; };
    return glint(1);
}

def generic_name_probe -> int {
    gleam = lambda (x: int) -> int { return x + 300; };
    return gleam(1);
}

def imported_probe -> int {
    return plain(1);
}
