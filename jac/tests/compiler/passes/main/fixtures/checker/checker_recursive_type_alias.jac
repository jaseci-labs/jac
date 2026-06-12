"""Recursive type alias with quoted forward refs (the JsonValue pattern).

The quoted 'Json' inside the alias's own RHS must resolve as a forward
reference to the alias (truncated gradually at depth 1 with Any), not as
a Literal["Json"] string type. Regression for the cluster where every
`dict[str, JsonValue]` return/assignment in runtimelib/server failed.
"""
import from typing { TypeAlias }

glob Json: TypeAlias = None | str | int | float | bool | list['Json'] | dict[
    (str, 'Json')
];

def flat() -> dict[str, Json] {
    return {'a': 'b'};
}

def nested() -> dict[str, Json] {
    envelope: dict[str, Json] = {
        'result': 'ok',
        'count': 3,
        'reports': [{'x': 1}]
    };
    return envelope;
}

def non_recursive_subscript_fwd() -> None {
    # Forward ref in a generic subscript outside the alias's own RHS.
    xs: list['Json'] = [None, 'a', 1];
    print(xs);
}
