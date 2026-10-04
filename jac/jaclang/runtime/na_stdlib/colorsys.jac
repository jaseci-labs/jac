glob ONE_THIRD: float = 1.0 / 3.0,
     ONE_SIXTH: float = 1.0 / 6.0,
     TWO_THIRD: float = 2.0 / 3.0;


def:pub rgb_to_yiq(r: float, g: float, b: float) -> tuple[float, float, float] {
    y: float = 0.30 * r + 0.59 * g + 0.11 * b;
    i: float = 0.74 * (r - y) - 0.27 * (b - y);
    q: float = 0.48 * (r - y) + 0.41 * (b - y);
    return (y, i, q);
}


def:pub yiq_to_rgb(y: float, i: float, q: float) -> tuple[float, float, float] {
    r: float = y + 0.9468822170900693 * i + 0.6235565819861433 * q;
    g: float = y - 0.27478764629897834 * i - 0.6356910791873801 * q;
    b: float = y - 1.1085450346420322 * i + 1.7090069284064666 * q;
    if r < 0.0 {
        r = 0.0;
    }
    if g < 0.0 {
        g = 0.0;
    }
    if b < 0.0 {
        b = 0.0;
    }
    if r > 1.0 {
        r = 1.0;
    }
    if g > 1.0 {
        g = 1.0;
    }
    if b > 1.0 {
        b = 1.0;
    }
    return (r, g, b);
}


def:pub rgb_to_hls(r: float, g: float, b: float) -> tuple[float, float, float] {
    maxc: float = r;
    if g > maxc {
        maxc = g;
    }
    if b > maxc {
        maxc = b;
    }
    minc: float = r;
    if g < minc {
        minc = g;
    }
    if b < minc {
        minc = b;
    }
    sumc: float = maxc + minc;
    rangec: float = maxc - minc;
    l: float = sumc / 2.0;
    if minc == maxc {
        return (0.0, l, 0.0);
    }
    s: float = 0.0;
    if l <= 0.5 {
        s = rangec / sumc;
    } else {
        s = rangec / (2.0 - maxc - minc);
    }
    rc: float = (maxc - r) / rangec;
    gc: float = (maxc - g) / rangec;
    bc: float = (maxc - b) / rangec;
    h: float = 0.0;
    if r == maxc {
        h = bc - gc;
    } elif g == maxc {
        h = 2.0 + rc - bc;
    } else {
        h = 4.0 + gc - rc;
    }
    h = (h / 6.0) % 1.0;
    return (h, l, s);
}


def _v(m1: float, m2: float, hue: float) -> float {
    h: float = hue % 1.0;
    if h < ONE_SIXTH {
        return m1 + (m2 - m1) * h * 6.0;
    }
    if h < 0.5 {
        return m2;
    }
    if h < TWO_THIRD {
        return m1 + (m2 - m1) * (TWO_THIRD - h) * 6.0;
    }
    return m1;
}


def:pub hls_to_rgb(h: float, l: float, s: float) -> tuple[float, float, float] {
    if s == 0.0 {
        return (l, l, l);
    }
    m2: float = 0.0;
    if l <= 0.5 {
        m2 = l * (1.0 + s);
    } else {
        m2 = l + s - (l * s);
    }
    m1: float = 2.0 * l - m2;
    return (_v(m1, m2, h + ONE_THIRD), _v(m1, m2, h), _v(m1, m2, h - ONE_THIRD));
}


def:pub rgb_to_hsv(r: float, g: float, b: float) -> tuple[float, float, float] {
    maxc: float = r;
    if g > maxc {
        maxc = g;
    }
    if b > maxc {
        maxc = b;
    }
    minc: float = r;
    if g < minc {
        minc = g;
    }
    if b < minc {
        minc = b;
    }
    rangec: float = maxc - minc;
    v: float = maxc;
    if minc == maxc {
        return (0.0, 0.0, v);
    }
    s: float = rangec / maxc;
    rc: float = (maxc - r) / rangec;
    gc: float = (maxc - g) / rangec;
    bc: float = (maxc - b) / rangec;
    h: float = 0.0;
    if r == maxc {
        h = bc - gc;
    } elif g == maxc {
        h = 2.0 + rc - bc;
    } else {
        h = 4.0 + gc - rc;
    }
    h = (h / 6.0) % 1.0;
    return (h, s, v);
}


def:pub hsv_to_rgb(h: float, s: float, v: float) -> tuple[float, float, float] {
    if s == 0.0 {
        return (v, v, v);
    }
    i: int = int(h * 6.0);
    f: float = (h * 6.0) - i;
    p: float = v * (1.0 - s);
    q: float = v * (1.0 - s * f);
    t: float = v * (1.0 - s * (1.0 - f));
    i = i % 6;
    if i == 0 {
        return (v, t, p);
    }
    if i == 1 {
        return (q, v, p);
    }
    if i == 2 {
        return (p, v, t);
    }
    if i == 3 {
        return (p, q, v);
    }
    if i == 4 {
        return (t, p, v);
    }
    return (v, p, q);
}
