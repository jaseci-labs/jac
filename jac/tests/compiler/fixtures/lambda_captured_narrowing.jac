obj Box {
    has n: int = 0;
}

def maybe -> Box | None {
    return Box(n=1);
}

def in_lambda -> int {
    b = maybe();
    if b is not None {
        f = lambda -> int { return b.n; };
        return f();
    }
    return 0;
}

def in_nested_def -> int {
    b = maybe();
    if b is not None {
        def g -> int {
            return b.n;
        }
        return g();
    }
    return 0;
}

def unguarded_lambda -> int {
    b = maybe();
    f = lambda -> int { return b.n; };
    return f();
}

def after_guarded_branch -> int {
    b = maybe();
    if b is None {
        h = lambda -> int { return 1; };
        h();
    }
    return b.n;
}
