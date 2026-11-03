"""Native dispatch through secondary bases and run-time graph types.

Both fixtures run natively under every memory profile and must print what the
Python backend prints.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

glob FIXTURES = Path(__file__).resolve().parent / "fixtures";

test "fields, methods and casts through a secondary base match Python" {
    out = assert_native_identity(
        str(FIXTURES / "secondary_base_dispatch.jac"), profiles=["managed", "rc"]
    );
    assert "X:name Y spec=X T:spec=T s:spec=s" in out.splitlines() , out;
}

test "edge types and walkers known only at run time match Python" {
    out = assert_native_identity(
        str(FIXTURES / "osp_dynamic_types.jac"), profiles=["managed", "rc"]
    );
    assert out.splitlines()[0] == "1 1 2" , out;
}
