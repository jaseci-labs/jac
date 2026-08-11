"""partition(n) shape errors are E1314: arity mismatch between n and
the unpack targets, a non-literal count, and a receiver that is not an
owned Region handle. A consumed unpacked child stays affine (E1301)."""

def bad_arity {
    r: own Region = Region();
    (a, b, c) = r.partition(2);
}

def bad_dynamic(k: int) {
    r: own Region = Region();
    (a, b) = r.partition(k);
}

def bad_receiver(q: Region) {
    (a, b) = q.partition(2);
}

def bad_reuse {
    r: own Region = Region();
    (a, b) = r.partition(2);
    fa = imm a;
    in a {
        print(1);
    }
}
