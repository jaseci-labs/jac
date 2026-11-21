"""JSX reserved props (key, ref) should not trigger E1101.

These are framework-level attributes consumed by the reconciler,
not forwarded to the component as props. They must be accepted
on any component without being declared in its parameter list."""

def Card(title: str, count: int = 0) -> JsxElement {
    return <div>{title}: {count}</div>;
}

with entry {
    # OK: key is a reserved JSX prop, should not error.
    a = <Card key="card-1" title="Hello"/>;

    # OK: ref is a reserved JSX prop, should not error.
    b = <Card ref="my-ref" title="World"/>;

    # OK: both reserved props together, should not error.
    c = <Card key="card-2" ref="r" title="Both" count={5}/>;

    # Error: 'bogus' is genuinely not a prop on Card (should still be E1101).
    d = <Card bogus="nope" title="Bad"/>;
}
