"""Regression: a TypeAlias union containing `Callable[..., Any]` after
another class arm (e.g. `type[Any]`) used to collapse to
`UnionType | type[Any]`, because `Callable[..., Any]` resolves to a
FunctionType — which the binary `|` evaluator did not recognize as a
valid union arm. It then fell into magic-method dispatch on the inner
UnionType, matched `type.__or__`'s typeshed signature
(`types.UnionType | Self`), and discarded every other arm.

`inspect.getfile` is annotated with exactly such an alias
(`_SourceObjectType` in typeshed), so every callable argument was
rejected with E1053. `JacBasics.jac_test` in `runtime.impl.jac` is the
canonical caller.

The fix is to treat `Callable[…]` annotations (FunctionType with empty
func_name) as valid union arms in `is_annotation_type`."""

import from inspect { getfile }
import from typing { Callable }


def test_fixture_call(test_fun: Callable) -> str {
    return getfile(test_fun);
}


def test_fixture_class(cls: type) -> str {
    return getfile(cls);
}
