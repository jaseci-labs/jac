"""A nested tuple target binds every name on the native tier."""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "nested tuple targets in a for header bind every name" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "nested_unpack_targets.jac"
    );
    out = assert_native_identity(source, profiles=["rc", "managed"]);
    for line in [
        "total 1800",
        "0:a:False 1:bb:True",
        "a=1/one b=2/two",
        "1 2 3",
        "4 5 6"
    ] {
        assert line in out , f"missing {line!r} in:\n{out}";
    }
}
