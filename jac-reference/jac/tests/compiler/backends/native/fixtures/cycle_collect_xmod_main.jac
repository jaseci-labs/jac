"""Cycles built in two modules, collected from each: every module's collector
must trace the objects the other module allocated."""
import from cycle_collect_xmod_shapes { Box, make_pair, read_drops, collect_there }

def local_pair {
    a = Box(tag=1);
    b = Box(tag=2);
    a.other = b;
    b.other = a;
}

with entry {
    for i in range(10) {
        make_pair();
        local_pair();
    }
    __rc_collect_cycles();
    print("collected_here", read_drops());
    for i in range(10) {
        make_pair();
        local_pair();
    }
    collect_there();
    print("collected_there", read_drops());
}
