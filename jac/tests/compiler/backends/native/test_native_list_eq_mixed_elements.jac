"""Lists whose elements are stored differently compare by value natively.

List equality only knew two lists of one native type. For any other pair it
fell through to comparing the two list pointers, so `list(struct.unpack(...))`
(elements held as tagged values) never equalled a `list[int]` with the same
contents, and a `list[int]` never equalled a `list[float]`. The answer was
False with no diagnostic. Such pairs are now compared element by element; a
native build refuses any demoted function, so identity with the Python
backend under every memory profile also proves the native path was taken.

Each element pair is compared as the kind its checked type names. An integer
against a float is compared exactly rather than through a rounding conversion,
so 2**53 + 1 does not equal 2.0**53. A bytearray shares its storage with a
list of bytes but is never equal to a list. An element a typed list keeps as
a bare pointer (a nested list, a dict, an object, a string) is tagged as what
it is before it meets a tagged value, so one object held by both lists equals
itself.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native equality of lists with different element storage agrees with Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "list_eq_mixed_elements.jac"
    );
    out = assert_native_identity(source);
    lines = out.splitlines();
    assert lines[0]
        == "[True, True, False, True, True, True, True, False, False]" , out;
    assert lines[1]
        == "[False, False, True, False, False, False, False, False, False]" , out;
    assert lines[2] == lines[0] , out;
    assert lines[3] == "[True, True, True, False, False]" , out;
    assert lines[4] == "[True, True, False, True]" , out;
    assert lines[5] == "[False, True, False, True, False, False, True, False]" , out;
    assert lines[6] == "[True, False, True, True, True]" , out;
    assert lines[7] == "[True, True, True, True, False, False]" , out;
    assert lines[8] == "[False, True, False, False, False, True, True]" , out;
    assert lines[9] == "[True, True, False, True, True, False, True, False]" , out;
}
