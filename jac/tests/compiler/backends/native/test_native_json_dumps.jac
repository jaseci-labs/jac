"""The native json.dumps writes what CPython writes.

Compile products cross the kernel boundary as JSON the host decodes, so the
native encoder has to agree with CPython's on everything a record holds:
`separators` and `ensure_ascii` behave as documented (non-ASCII text escapes
by default, astral characters as surrogate pairs), non-finite floats spell
NaN and Infinity, and a value JSON cannot hold raises instead of encoding
as null.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native json.dumps matches CPython on separators, escapes and floats" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "json_dumps_fidelity.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert '"edges": [["web", "api"], ["api", "db"]]' in out , out;
    assert '\\u00e9' in out and '\\ud83d\\ude00' in out , out;
}
