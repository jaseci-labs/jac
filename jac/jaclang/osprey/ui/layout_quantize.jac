glob:priv EPSILON: float = 1e-8;

glob _NO_MIN: float = -1e308,
     _NO_MAX: float = 1e308;


obj PartitionRequest {
    has span: int,
        targets: list[float],
        fixed: list[bool] = [],
        minimums: list[float] = [],
        maximums: list[float] = [];
}


obj QuantizeResult {
    has ok: bool = True,
        sizes: list[int] = [],
        message: str = "",
        index: int = -1;
}


def _floor(value: float) -> int;


def _ceil(value: float) -> int;


def snap_edge(value: float) -> int;


def snap_edge_group(values: list[float]) -> list[int];


def _quant_fail(message: str, index: int) -> QuantizeResult;


def _bounds_ok_shape(req: PartitionRequest) -> bool;


def quantize_partition(req: PartitionRequest) -> QuantizeResult;


def _apply_bounds(
    req: PartitionRequest,
    sizes: list[int],
    flexible: list[int],
    remainders: list[float],
) -> QuantizeResult;

impl _floor(value: float) -> int {
    t = int(value);
    if value >= 0.0 or float(t) == value {
        return t;
    }
    return t - 1;
}


impl _ceil(value: float) -> int {
    neg = -value;
    f = _floor(neg);
    return -f;
}


impl snap_edge(value: float) -> int {
    fl = _floor(value);
    frac = value - float(fl);
    if frac < EPSILON {
        return fl;
    }
    if frac > 1.0 - EPSILON {
        return fl + 1;
    }
    if frac > 0.5 {
        return fl + 1;
    }
    return fl;
}


impl snap_edge_group(values: list[float]) -> list[int] {
    rep = snap_edge(values[0]);
    out: list[int] = [];
    for _v in values {
        out.append(rep);
    }
    return out;
}


impl _quant_fail(message: str, index: int) -> QuantizeResult {
    return QuantizeResult(ok=False, message=message, index=index);
}


impl _bounds_ok_shape(req: PartitionRequest) -> bool {
    n = len(req.targets);
    if len(req.fixed) != 0 and len(req.fixed) != n {
        return False;
    }
    if len(req.minimums) != 0 and len(req.minimums) != n {
        return False;
    }
    if len(req.maximums) != 0 and len(req.maximums) != n {
        return False;
    }
    return True;
}


impl quantize_partition(req: PartitionRequest) -> QuantizeResult {
    if not _bounds_ok_shape(req) or req.span < 0 {
        return _quant_fail("malformed partition request", -1);
    }
    n = len(req.targets);
    if n == 0 {
        if req.span != 0 {
            return _quant_fail("nonempty span with no children", -1);
        }
        return QuantizeResult(ok=True);
    }

    fixed_flags: list[bool] = [];
    if len(req.fixed) == 0 {
        for _i in range(n) {
            fixed_flags.append(False);
        }
    } else {
        for f in req.fixed {
            fixed_flags.append(f);
        }
    }

    sizes: list[int] = [0] * n;
    floors: list[int] = [0] * n;
    remainders: list[float] = [0.0] * n;
    fixed_sum = 0;

    for i in range(n) {
        t = req.targets[i];
        if t < 0.0 {
            return _quant_fail("negative continuous target", i);
        }
        if fixed_flags[i] {
            sizes[i] = snap_edge(t);
            fixed_sum += sizes[i];
        } else {
            floors[i] = _floor(t);
            remainders[i] = t - float(floors[i]);
            sizes[i] = floors[i];
        }
    }

    leftover = req.span - fixed_sum;
    for i in range(n) {
        if not fixed_flags[i] {
            leftover -= floors[i];
        }
    }

    if leftover < 0 {
        recoverable = True;
        for i in range(n) {
            if not fixed_flags[i] and floors[i] > 0 {
                recoverable = False;
            }
        }
        if recoverable {
            return _quant_fail("fixed integer claims exceed parent span", -1);
        }
        return _quant_fail(
            "flexible floors exceed remaining span under largest-remainder policy", -1
        );
    }

    flexible: list[int] = [];
    for i in range(n) {
        if not fixed_flags[i] {
            flexible.append(i);
        }
    }
    if 0 < len(flexible) < 3 {
        sizes[flexible[len(flexible) - 1]] += leftover;
        leftover = 0;
    }

    while leftover > 0 and len(flexible) {
        best = -1;
        for i in flexible {
            if best == -1 or remainders[i] > remainders[best] + EPSILON {
                best = i;
            }
        }
        sizes[best] += 1;
        remainders[best] -= 1.0;
        leftover -= 1;
    }

    res = _apply_bounds(req, sizes, flexible, remainders);
    return res;
}


impl _apply_bounds(
    req: PartitionRequest,
    sizes: list[int],
    flexible: list[int],
    remainders: list[float],
) -> QuantizeResult {
    if len(req.minimums) == 0 and len(req.maximums) == 0 {
        if sum(sizes) != req.span {
            return _quant_fail("partition does not close on span", -1);
        }
        for i in range(len(sizes)) {
            if sizes[i] < 0 {
                return _quant_fail("negative derived size", i);
            }
        }
        return QuantizeResult(ok=True, sizes=sizes);
    }

    imin: list[int] = [];
    imax: list[int] = [];
    for i in range(len(req.targets)) {
        mn = _NO_MIN;
        mx = _NO_MAX;
        if len(req.minimums) != 0 {
            mn = req.minimums[i];
        }
        if len(req.maximums) != 0 {
            mx = req.maximums[i];
        }
        lo = _ceil(mn);
        hi = _floor(mx);
        if lo > hi {
            return _quant_fail("bound interval contains no integer cell size", i);
        }
        imin.append(lo);
        imax.append(hi);
    }

    for _round in range(8) {
        delta = 0;
        clamped: list[int] = [];
        for i in flexible {
            if sizes[i] < imin[i] {
                delta -= imin[i] - sizes[i];
                sizes[i] = imin[i];
                clamped.append(i);
            } elif sizes[i] > imax[i] {
                delta += sizes[i] - imax[i];
                sizes[i] = imax[i];
                clamped.append(i);
            }
        }
        if delta == 0 {
            break;
        }

        movable: list[int] = [];
        for i in flexible {
            is_clamped = False;
            for c in clamped {
                if c == i {
                    is_clamped = True;
                }
            }
            if not is_clamped {
                movable.append(i);
            }
        }
        steps = abs(delta);
        for _s in range(steps) {
            best = -1;
            for i in movable {
                if delta > 0 and imax[i] - sizes[i] <= 0 {
                    continue;
                }
                if delta < 0 and sizes[i] - imin[i] <= 0 {
                    continue;
                }
                if best == -1 {
                    best = i;
                    continue;
                }
                if delta > 0 and remainders[i] > remainders[best] {
                    best = i;
                }
                if delta < 0 and remainders[i] < remainders[best] {
                    best = i;
                }
            }
            if best == -1 {
                return _quant_fail("bound repair could not restore closure", -1);
            }
            if delta > 0 {
                sizes[best] += 1;
            } else {
                sizes[best] -= 1;
            }
        }
        if not clamped {
            break;
        }
    }
    if sum(sizes) != req.span {
        return _quant_fail("partition does not close on span", -1);
    }
    for i in range(len(sizes)) {
        if sizes[i] < 0 {
            return _quant_fail("negative derived size", i);
        }
    }
    return QuantizeResult(ok=True, sizes=sizes);
}
