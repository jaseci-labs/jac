import from xmod_gc_lib { Pool, pool_new, pool_set, pool_sum }

def run -> float {
    p: own Pool = pool_new();
    pool_set(&mut p, 0, 2.5);
    pool_set(&mut p, 1, 1.5);
    return pool_sum(&p);
}

with entry {
    run();
}
