"""Null-safe access (`a?.b`, `a?[i]`) on the native tier.

The native generator used to lower `a?.b` as `a.b`: a `None` receiver raised
`AttributeError` where the Python tier answers `None`. The compiler's own
sources lean on the Python meaning, so the generator could not run natively
until this held."""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "null-safe access answers None natively as the Python tier does" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "null_safe_access.jac");
    out = assert_native_identity(source, profiles=["rc", "managed"]);
    for line in [
        "int none 5",
        "name none n made! none",
        "ratio none 0.5",
        "flag False True False",
        "deep n n y -1 -1 6",
        "extra none 7 False True",
        "label none none bee",
        "count -1 3",
        "index none 4",
        "temp True 4",
        "total 750 5",
        "module a other"
    ] {
        assert line in out , f"missing {line!r} in:\n{out}";
    }
}
