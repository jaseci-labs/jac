"""GraphMend: classify torch attributes as data-dependent (dynamic) or static.

A table of torch attributes/methods whose result depends on tensor *data* --
returning a Python scalar, forcing a CPU<->GPU sync, or producing a value/shape
TorchDynamo cannot determine statically. When one appears in a branch condition
(directly or transitively), the branch is a data-dependent graph break. Extend
by adding a name to `DYNAMIC_TORCH_ATTRS`.
"""

# Torch ops/attributes whose result depends on tensor *data* (not just static
# shape), so using them in a branch condition forces a graph break.
glob DYNAMIC_TORCH_ATTRS: set[str] = {
         'item',
         'tolist',
         'sum',
         'max',
         'min',
         'mean',
         'prod',
         'argmax',
         'argmin',
         'nonzero',
         'count_nonzero',
         'all',
         'any',
         'equal',
         'allclose',
         'unique'
     },
     # Substrings (lower-cased) identifying logging-style side-effect calls.
     LOGGING_PATTERNS: list[str] = ['logger', 'logging', 'warn', 'critical'],
     # Built-in side-effecting calls that break tracing when seen inside a graph.
     SIDE_EFFECT_CALLS: set[str] = {'print'};

"""Return True if `attr` names a data-dependent (dynamic) torch attribute."""
def is_dynamic_torch_attr(attr: str) -> bool {
    return attr in DYNAMIC_TORCH_ATTRS;
}

"""True if `name` is a logging/printing side-effect call -- the builtin `print`,
or a name containing a logging keyword (e.g. `logger.warning`)."""
def is_side_effect_name(name: str) -> bool {
    if name in SIDE_EFFECT_CALLS {
        return True;
    }
    lowered = name.lower();
    for pattern in LOGGING_PATTERNS {
        if pattern in lowered {
            return True;
        }
    }
    return False;
}
