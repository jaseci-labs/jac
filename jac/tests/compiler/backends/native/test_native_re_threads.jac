import from pathlib { Path }
import from tests.support { assert_native_identity }

def fixture(name: str) -> str {
    return str(Path(__file__).resolve().parent / "fixtures" / name);
}

"""re's compiled-pattern cache is shared by every thread, and so is each
compiled Pattern's scratch state. flow workers compiling past the cache size,
purging it, and searching one shared Pattern must each get their own answers."""
test "flow workers share the re cache and a compiled pattern safely" {
    out = assert_native_identity(
        fixture("re_flow_threads.jac"), profiles=["rc", "managed"]
    );
    assert out == "bad 0\n" , out;
}
