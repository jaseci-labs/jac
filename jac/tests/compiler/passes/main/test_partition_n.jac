"""partition(n) sugar -- the n-ary form of the per-child call (#7870
item 6a). `(a, b) = r.partition(2)` unpacks an owned region into n
owned child handles riding the same reabsorb/zombie contract; the
checker licenses exactly that shape (literal count matching the unpack
arity, owned Region receiver) and stamps the targets as affine owned
handles. Every other partition-with-arguments shape is E1314."""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "matching literal unpack of an owned region is clean" {
    prog = compile_fixture("partition_n_ok.jac");
    expect_ownership_codes(prog, []);
}

test "arity mismatch, dynamic count, unowned receiver are E1314; children stay affine" {
    prog = compile_fixture("partition_n_bad.jac");
    expect_ownership_codes(
        prog, ["E1301", "E1301", "E1301", "E1314", "E1314", "E1314"]
    );
}
