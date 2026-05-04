"""Regression: a TypeAlias union with `Callable[..., Any]` after another
class arm (e.g. `type[Any]`) used to collapse to `UnionType | type[Any]`,
because `Callable[..., Any]` resolves to a FunctionType — which the
binary `|` evaluator did not recognize as a valid union arm. It then
fell into magic-method dispatch on the inner UnionType, which returned
the typeshed signature of `type.__or__` (`UnionType | Self`) and
discarded every other arm.

The fix is to treat `Callable[…]` annotations (FunctionType with empty
func_name) as valid union arms in `is_annotation_type`. This mirrors
how `inspect.getfile` (typed `_SourceObjectType` in typeshed) is called
throughout jaclang."""

import from inspect { getfile }
import from typing { Any, Callable }
import from types {
    ModuleType,
    MethodType,
    FunctionType,
    TracebackType,
    FrameType,
    CodeType
}


def take_module(m: ModuleType) -> str {
    return getfile(m);
}
def take_class(c: type[Any]) -> str {
    return getfile(c);
}
def take_method(m: MethodType) -> str {
    return getfile(m);
}
def take_function(f: FunctionType) -> str {
    return getfile(f);
}
def take_traceback(t: TracebackType) -> str {
    return getfile(t);
}
def take_frame(f: FrameType) -> str {
    return getfile(f);
}
def take_code(c: CodeType) -> str {
    return getfile(c);
}
def take_callable(c: Callable) -> str {
    return getfile(c);
}
