"""Lists whose elements are stored differently compare by value natively.

List equality only knew two lists of one native type. For any other pair it
fell through to comparing the two list pointers, so `list(struct.unpack(...))`
(elements held as tagged values) never equalled a `list[int]` with the same
contents, and a `list[int]` never equalled a `list[float]`. The answer was
False with no diagnostic. Such pairs are now compared element by element; a
native build refuses any demoted function, so identity with the Python
backend under every memory profile also proves the native path was taken.
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
}
