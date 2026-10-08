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
