def:pub fmean[T](data: list[T]) -> float;

def:pub mean[T](data: list[T]) -> float;

def:pub median[T](data: list[T]) -> float;

def:pub median_low[T](data: list[T]) -> float;

def:pub median_high[T](data: list[T]) -> float;

def:pub pvariance[T](data: list[T]) -> float;

def:pub variance[T](data: list[T]) -> float;

def:pub pstdev[T](data: list[T]) -> float;

def:pub stdev[T](data: list[T]) -> float;

impl fmean[T](data: list[T]) -> float {
    n = len(data);
    if n == 0 {
        raise ValueError("fmean requires at least one data point");
    }
    s = 0.0;
    for x in data {
        s = s + float(x);
    }
    return s / float(n);
}

impl mean[T](data: list[T]) -> float {
    n = len(data);
    if n == 0 {
        raise ValueError("mean requires at least one data point");
    }
    s = 0.0;
    for x in data {
        s = s + float(x);
    }
    return s / float(n);
}

impl median[T](data: list[T]) -> float {
    n = len(data);
    if n == 0 {
        raise ValueError("no median for empty data");
    }
    xs = sorted(data);
    m = n // 2;
    if n % 2 == 1 {
        return float(xs[m]);
    }
    return (float(xs[m - 1]) + float(xs[m])) / 2.0;
}

impl median_low[T](data: list[T]) -> float {
    n = len(data);
    if n == 0 {
        raise ValueError("no median for empty data");
    }
    xs = sorted(data);
    if n % 2 == 1 {
        return float(xs[n // 2]);
    }
    return float(xs[n // 2 - 1]);
}

impl median_high[T](data: list[T]) -> float {
    n = len(data);
    if n == 0 {
        raise ValueError("no median for empty data");
    }
    xs = sorted(data);
    return float(xs[n // 2]);
}

impl pvariance[T](data: list[T]) -> float {
    n = len(data);
    if n < 1 {
        raise ValueError("pvariance requires at least one data point");
    }
    mu = 0.0;
    for x in data {
        mu = mu + float(x);
    }
    mu = mu / float(n);
    ss = 0.0;
    for x in data {
        d = float(x) - mu;
        ss = ss + d * d;
    }
    return ss / float(n);
}

impl variance[T](data: list[T]) -> float {
    n = len(data);
    if n < 2 {
        raise ValueError("variance requires at least two data points");
    }
    mu = 0.0;
    for x in data {
        mu = mu + float(x);
    }
    mu = mu / float(n);
    ss = 0.0;
    for x in data {
        d = float(x) - mu;
        ss = ss + d * d;
    }
    return ss / float(n - 1);
}

impl pstdev[T](data: list[T]) -> float {
    return pvariance(data) ** 0.5;
}

impl stdev[T](data: list[T]) -> float {
    return variance(data) ** 0.5;
}
