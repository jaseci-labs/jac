"""A local re-annotated with another type holds the new type from there on.

The type checker gives a symbol one declared type (its first annotation), so
MIR typed every use of `s` in `if ... { s: str = ...; } s: int = ...;
float(s)` as a str: the int was stored into the str slot and float(s)
parsed it as text. js_engine's ToTemporalDurationValue has that shape, and
every Temporal duration built from a property bag failed with "could not
convert string to float: ''". A re-annotated local now gets a slot of its
new type, used by the reads lowered after it, as the NaIRGen backend did.
"""

import from pathlib { Path }
import from tests.support { assert_native_identity }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "a re-annotated local takes its new type" {
    out = assert_native_identity(
        str(FIXTURES / "redeclared_local.jac"), profiles=["rc", "managed"]
    );
    assert out.splitlines() == ["42.0 4.0", "row 2", "13"] , out;
}
