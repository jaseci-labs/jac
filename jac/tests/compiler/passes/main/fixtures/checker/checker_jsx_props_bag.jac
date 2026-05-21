"""Props-bag components: a component declared with a single parameter named
`props` receives all JSX attributes as one object.

- An untyped props bag (`props: any`) accepts any JSX attribute (no E1101)
  but is flagged once at its definition with W1052.
- A typed props bag validates JSX attributes against the members of the
  props object's type (E1101 for unknown props, E1100 for type mismatches)
  and is NOT flagged with W1052."""

obj TypedProps {
    has title: str,
        count: int;
}

# Untyped props bag — opts out of prop checking, emits W1052 at this line.
def UntypedComp(props: any) -> JsxElement {
    return <div>{props.title}</div>;
}

# Typed props bag — fully checked, no W1052.
def TypedComp(props: TypedProps) -> JsxElement {
    return <div>{props.title}</div>;
}

with entry {
    # OK: untyped bag accepts arbitrary attributes — no E1101.
    a = <UntypedComp title="hi" anything={42} whatever="x"/>;

    # OK: typed bag with valid props.
    b = <TypedComp title="hi" count={3}/>;

    # Error: 'bogus' is not a member of TypedProps -> E1101.
    c = <TypedComp title="hi" count={3} bogus={1}/>;

    # Error: 'count' expects int, got str -> E1100.
    d = <TypedComp title="hi" count="nope"/>;
}
