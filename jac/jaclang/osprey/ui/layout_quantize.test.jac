def _req(
    span: int,
    targets: list[float],
    fixed: list[bool] = [],
    minimums: list[float] = [],
    maximums: list[float] = [],
) -> PartitionRequest;


test "snap_edge rounds halves toward the smaller coordinate" {
    assert snap_edge(2.5) == 2;
    assert snap_edge(3.5) == 3;
    assert snap_edge(-2.5) == -3;
    assert snap_edge(-0.5) == -1;
}


test "snap_edge handles ordinary rounding and negatives" {
    assert snap_edge(2.7) == 3;
    assert snap_edge(2.3) == 2;
    assert snap_edge(-0.2) == 0;
    assert snap_edge(-1.7) == -2;
    assert snap_edge(0.0) == 0;
}


test "snap_edge snaps EPSILON-close values to integers" {
    assert snap_edge(4.0 + 1e-10) == 4;
    assert snap_edge(4.0 - 1e-10) == 4;
    assert snap_edge(6.99999999999) == 7;
}


test "snap_edge_group snaps once for the whole group" {
    g = snap_edge_group([3.0, 3.0 + 5e-11, 3.0 - 5e-11]);
    assert g[0] == 3;
    assert g[1] == 3;
    assert g[2] == 3;
}


test "partition with exact integer targets is identity" {
    r = quantize_partition(_req(24, [1.0, 20.0, 3.0]));
    assert r.ok;
    assert r.sizes == [1, 20, 3];
}


test "largest remainder ties break to the lowest index (rank order)" {
    r = quantize_partition(_req(10, [10.0 / 3.0, 10.0 / 3.0, 10.0 / 3.0]));
    assert r.ok;
    assert r.sizes == [4, 3, 3];
    assert sum(r.sizes) == 10;
}


test "two flexible children bias leftover to the last (legacy parity)" {
    r = quantize_partition(_req(5, [2.5, 2.5]));
    assert r.ok;
    assert r.sizes == [2, 3];
    assert sum(r.sizes) == 5;
}


test "single flexible child absorbs the whole leftover" {
    r = quantize_partition(_req(7, [6.5]));
    assert r.ok;
    assert r.sizes == [7];
}


test "unequal weights below three still match int-share-then-remainder" {
    r = quantize_partition(_req(7, [14.0 / 3.0, 7.0 / 3.0]));
    assert r.ok;
    assert r.sizes == [4, 3];
}


test "distinct remainders distribute by descending fraction" {
    r = quantize_partition(_req(10, [2.9, 3.6, 3.5]));
    assert r.ok;
    assert r.sizes == [3, 4, 3];
    assert sum(r.sizes) == 10;
}


test "second distribution pass when leftover exceeds child count" {
    r = quantize_partition(_req(11, [3.7, 3.7, 3.6]));
    assert r.ok;
    assert r.sizes == [4, 4, 3];
}


test "fixed claims stay fixed during distribution" {
    r = quantize_partition(_req(10, [3.0, 3.5, 3.5], fixed=[True, False, False]));
    assert r.ok;
    assert r.sizes == [3, 3, 4];
}


test "every flexible child stays within one cell of its target" {
    r = quantize_partition(_req(40, [7.3, 12.9, 19.8]));
    assert r.ok;
    assert abs(float(r.sizes[0]) - 7.3) < 1.0;
    assert abs(float(r.sizes[1]) - 12.9) < 1.0;
    assert abs(float(r.sizes[2]) - 19.8) < 1.0;
    assert sum(r.sizes) == 40;
}


test "bound interval without an integer cell size is rejected" {
    r = quantize_partition(_req(10, [2.5], minimums=[], maximums=[]),);
    _ = r;
    r2 = quantize_partition(
        _req(10, [2.5, 7.5], minimums=[2.2, 0.0], maximums=[2.8, 100.0])
    );
    assert not r2.ok;
    assert r2.index == 0;
    assert r2.sizes == [];
}


test "negative residual after overflow clips reports failure not lies" {
    r = quantize_partition(_req(5, [4.0, 3.0], fixed=[True, False]));
    assert not r.ok;
    assert r.index == -1;
}


test "flexible floors that cannot close the deficit report failure" {
    r = quantize_partition(_req(5, [4.2, 4.8]));
    assert not r.ok;
}


test "bound clamp triggers repair that restores closure" {
    r = quantize_partition(
        _req(5, [2.1, 2.9], minimums=[0.0, 0.0], maximums=[100.0, 2.5])
    );
    assert r.ok;
    assert r.sizes == [3, 2];
    assert sum(r.sizes) == 5;
}


test "empty partition requires empty span" {
    ok = quantize_partition(_req(0, []));
    assert ok.ok;
    bad = quantize_partition(_req(4, []));
    assert not bad.ok;
}


test "negative span or malformed shapes are rejected" {
    assert not quantize_partition(_req(-1, [1.0])).ok;
    assert not quantize_partition(_req(4, [2.0, 2.0], minimums=[1.0])).ok;
}

impl _req(
    span: int,
    targets: list[float],
    fixed: list[bool] = [],
    minimums: list[float] = [],
    maximums: list[float] = [],
) -> PartitionRequest {
    return PartitionRequest(
        span=span, targets=targets, fixed=fixed, minimums=minimums, maximums=maximums,
    );
}
