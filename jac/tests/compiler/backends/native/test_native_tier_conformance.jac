"""Programs the native tier ran and answered differently from the Python tier.

Each case here was found by the tier census (`tests/tier_census.jac`): an
ordinary program, not written for the native tier, that lowered, ran to the
end and printed something else. A refusal is loud; these were not."""
import from pathlib { Path }
import from tests.support { assert_native_identity }

def fixture(name: str) -> str {
    return str(Path(__file__).resolve().parent / "fixtures" / name);
}

"""A `switch` falls through: once a case matches, every later case runs until
a `break`, the default included, and a default that is reached before any
match runs too. The native lowering ran one case and left, skipped a case
with no body, and dropped a case that names several values."""
test "a switch falls through to the next case until a break" {
    out = assert_native_identity(
        fixture("switch_fallthrough.jac"), profiles=["rc", "managed"]
    );
    assert "banana ['banana-or-orange', 'grape']" in out , out;
    assert "kiwi ['kiwi-or-lime', 'default:kiwi']" in out , out;
    assert "3 many nine" in out , out;
    assert "5109" in out , out;
}

"""`(a, b) = pair` inside a function, where `a` and `b` are module globals,
assigns the globals, as `a = x` does. The native lowering bound two locals
and the globals kept their old values."""
test "a tuple assignment to module globals writes the globals" {
    out = assert_native_identity(
        fixture("unpack_into_globals.jac"), profiles=["rc", "managed"]
    );
    assert "World Hello 1" in out , out;
    assert "y1 y2 3" in out , out;
    assert "['p', 'q'] q lr" in out , out;
}

"""`3 == 3.0` and `True == 1` hold whatever the static types are. Two untyped
values were equal on the native tier only when they were the same kind of
number, so `x as int as float == 3.0` was false for `x: any = 3`."""
test "untyped numbers of different kinds compare by value" {
    out = assert_native_identity(
        fixture("any_number_equality.jac"), profiles=["rc", "managed"]
    );
    assert "True True True True True" in out , out;
    assert "False False False False True" in out , out;
    assert "True True True False" in out , out;
}

"""An archetype is a dataclass on the Python tier, so printing one writes
`Name(field=value, ...)`. The native tier wrote `<Name object at 0x...>`,
which is different text and a different one every run."""
test "an object without its own repr prints its fields" {
    out = assert_native_identity(
        fixture("default_object_text.jac"), profiles=["rc", "managed"]
    );
    assert "Named(x=1, y=2.0, label=\"it's\", tags=['a', 'b'])" in out , out;
    assert "Holder(inner=Point(x=3, y=1.5), maybe=None, flag=True)" in out , out;
    assert "Link(name='a', nxt=Link(name='b', nxt=None))" in out , out;
    assert "Bag(counts={'x': 1}, seen={1}, pair=(1, 'a'), anything='q', ratio=0.1)"
        in out , out;
    assert "Tour(depth=2) Road(km=9)" in out , out;
}

"""The text follows the object, not the type it is held as: a subclass
instance held as its base prints the subclass's name and fields, or runs the
subclass's own `__repr__`."""
test "default object text follows the runtime class" {
    out = assert_native_identity(
        fixture("default_object_text_subclass.jac"), profiles=["rc", "managed"]
    );
    assert "Shape(sides=0) Square(sides=4, width=2) Named<q>" in out , out;
    assert "[Square(sides=4, width=2), Shape(sides=0), Named<q>]" in out , out;
}

"""An ability triggered by `Root` runs at the root node only. The native
tier has no root node of its own and read the name as "any location", so
`with Root | Stop entry` ran at every node, and twice at a `Stop`. An
ability whose trigger names a base and its subclass does run twice at the
subclass, on both tiers."""
test "a Root trigger does not match every node" {
    out = assert_native_identity(
        fixture("union_trigger_abilities.jac"), profiles=["rc", "managed"]
    );
    assert "['ab', 'a'] ['ab'] ['root-or-c']" in out , out;
    assert "['either', 'either', 'leaving', 'leaving'] ['either', 'leaving']"
        in out , out;
}
