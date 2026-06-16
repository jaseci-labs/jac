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
     # logging.Logger method names; a `<logger>.<method>(...)` call with one of
     # these breaks tracing. Matched against the CALL's method name (not a
     # substring of the callee), so `setup_logging()` is not a false positive.
     # The generic `log` is excluded: it collides with non-logging methods like
     # PyTorch Lightning's `self.log("metric", v)`, and the stdlib alias
     # `logger.log(level, msg)` is rarely called directly.
     LOG_METHODS: set[str] = {
         'debug',
         'info',
         'warning',
         'warning_once',
         'error',
         'exception',
         'critical',
         'fatal',
         'warn'
     },
     # Built-in side-effecting calls that break tracing when seen inside a graph.
     SIDE_EFFECT_CALLS: set[str] = {'print'};

"""Return True if `attr` names a data-dependent (dynamic) torch attribute."""
def is_dynamic_torch_attr(attr: str) -> bool {
    return attr in DYNAMIC_TORCH_ATTRS;
}

"""True if `name` is a side-effecting call that breaks tracing: the builtin
`print`, or a logging.Logger method (`debug`/`info`/`warning`/...). For an
attribute call this is matched against the method name, e.g. `warning` in
`logger.warning(...)`."""
def is_side_effect_name(name: str) -> bool {
    return (name in SIDE_EFFECT_CALLS) or (name in LOG_METHODS);
}
