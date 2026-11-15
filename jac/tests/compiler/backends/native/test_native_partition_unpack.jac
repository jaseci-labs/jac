"""`(head, found, tail) = text.partition(mark)` unpacks what the call returned.

Natively `str.partition` hands back a list of three strings, while its
checked type is a three-string tuple. Unpacking trusted the type, read the
list's header as tuple fields and crashed; indexing the same value worked.
The kernel's compile-time evaluator folds `partition` with exactly that
unpack, so any program calling it on a constant took the kernel down.
Unpacking now reads the value it was given.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "unpacking a partition result reads its three parts" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "partition_unpack.jac");
    out = assert_native_identity(source, profiles=["managed"]);
    lines = out.splitlines();
    assert lines[-3] == "a<,>b,c abc<>" , out;
    assert lines[-2] == "a,b<,>c <>abc" , out;
    assert lines[-1] == "a<,>b,c a,b<,>c" , out;
}
