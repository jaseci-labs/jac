"""Two modules' same-named classes, both used from a third module."""

import from bz_state {
    CompressorState as BzState,
    make_state as make_bz,
    is_state as is_bz,
    describe_all as describe_bz
}
import from zs_state {
    CompressorState as ZsState,
    make_state as make_zs,
    is_state as is_zs,
    describe_all as describe_zs
}

obj TracedBz(BzState) {
    def describe -> str {
        return "traced " + super.describe();
    }
}

with entry {
    bz: own BzState = make_bz(9);
    zs: own ZsState = make_zs(0.25);
    zs.feed(4);
    local_bz: own BzState = BzState(level=3, flushed=True, label="local");
    local_zs: own ZsState = ZsState();
    local_zs.feed(10);
    print(bz.describe(), zs.describe());
    print(local_bz.describe(), local_zs.describe());
    first_bz: own BzState = make_bz(1);
    first_zs: own ZsState = make_zs(0.75);
    bz_list: own list[BzState] = [first_bz, BzState(level=2, label="fresh")];
    zs_list: own list[ZsState] = [first_zs, ZsState(ratio=2.0)];
    print(describe_bz(&bz_list), describe_zs(&zs_list));
    print(is_bz(&bz), is_bz(&zs), is_zs(&zs), is_zs(&bz));
    print(isinstance(local_bz, BzState), isinstance(local_bz, ZsState));
    traced: own TracedBz = TracedBz(level=5);
    print(is_bz(&traced), is_zs(&traced), isinstance(traced, BzState));
    print(bz.level + len(zs.chunks), zs.ratio * 2, traced.describe());
    print(type(bz).__name__, type(zs).__name__);
}
