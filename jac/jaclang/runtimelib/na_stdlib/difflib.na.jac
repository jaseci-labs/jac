def _zeros(n: int) -> list[int] {
    out: list[int] = [];
    i: int = 0;
    while i < n {
        out.append(0);
        i += 1;
    }
    return out;
}


def _str_gt(a: str, b: str) -> bool {
    m: int = len(a);
    if len(b) < m {
        m = len(b);
    }
    i: int = 0;
    while i < m {
        ca: int = ord(a[i]);
        cb: int = ord(b[i]);
        if ca != cb {
            return ca > cb;
        }
        i += 1;
    }
    return len(a) > len(b);
}


def _popular_flags(b: str, autojunk: bool) -> list[int] {
    n: int = len(b);
    flags: list[int] = _zeros(n);
    if not autojunk or n < 200 {
        return flags;
    }
    counts: dict[str, int] = {};
    i: int = 0;
    while i < n {
        ch: str = b[i];
        counts[ch] = counts.get(ch, 0) + 1;
        i += 1;
    }
    ntest: int = n // 100 + 1;
    j: int = 0;
    while j < n {
        if counts.get(b[j], 0) > ntest {
            flags[j] = 1;
        }
        j += 1;
    }
    return flags;
}


def _find_longest_match(
    a: str, b: str, alo: int, ahi: int, blo: int, bhi: int, popular: list[int]
) -> list[int] {
    besti: int = alo;
    bestj: int = blo;
    bestsize: int = 0;
    lb: int = len(b);
    prev: list[int] = _zeros(lb);
    i: int = alo;
    while i < ahi {
        cur: list[int] = _zeros(lb);
        ai: int = ord(a[i]);
        j: int = blo;
        while j < bhi {
            if popular[j] == 0 and ord(b[j]) == ai {
                pv: int = 0;
                if j > blo {
                    pv = prev[j - 1];
                }
                k: int = pv + 1;
                cur[j] = k;
                if k > bestsize {
                    besti = i - k + 1;
                    bestj = j - k + 1;
                    bestsize = k;
                }
            }
            j += 1;
        }
        prev = cur;
        i += 1;
    }
    while besti > alo and bestj > blo and ord(a[besti - 1]) == ord(b[bestj - 1]) {
        besti -= 1;
        bestj -= 1;
        bestsize += 1;
    }
    while besti + bestsize < ahi
    and bestj + bestsize < bhi
    and ord(a[besti + bestsize]) == ord(b[bestj + bestsize]) {
        bestsize += 1;
    }
    return [besti, bestj, bestsize];
}


def _matching_blocks(a: str, b: str, autojunk: bool) -> list[list[int]] {
    la: int = len(a);
    lb: int = len(b);
    popular: list[int] = _popular_flags(b, autojunk);
    queue: list[list[int]] = [[0, la, 0, lb]];
    raw: list[list[int]] = [];
    while len(queue) > 0 {
        box: list[int] = queue.pop();
        alo: int = box[0];
        ahi: int = box[1];
        blo: int = box[2];
        bhi: int = box[3];
        m: list[int] = _find_longest_match(a, b, alo, ahi, blo, bhi, popular);
        i: int = m[0];
        j: int = m[1];
        k: int = m[2];
        if k > 0 {
            raw.append(m);
            if alo < i and blo < j {
                queue.append([alo, i, blo, j]);
            }
            if i + k < ahi and j + k < bhi {
                queue.append([i + k, ahi, j + k, bhi]);
            }
        }
    }
    _sort_blocks(raw);
    result: list[list[int]] = [];
    i1: int = 0;
    j1: int = 0;
    k1: int = 0;
    idx: int = 0;
    while idx < len(raw) {
        bi: int = raw[idx][0];
        bj: int = raw[idx][1];
        bk: int = raw[idx][2];
        if i1 + k1 == bi and j1 + k1 == bj {
            k1 += bk;
        } else {
            if k1 > 0 {
                result.append([i1, j1, k1]);
            }
            i1 = bi;
            j1 = bj;
            k1 = bk;
        }
        idx += 1;
    }
    if k1 > 0 {
        result.append([i1, j1, k1]);
    }
    result.append([la, lb, 0]);
    return result;
}


def _block_lt(x: list[int], y: list[int]) -> bool {
    if x[0] != y[0] {
        return x[0] < y[0];
    }
    if x[1] != y[1] {
        return x[1] < y[1];
    }
    return x[2] < y[2];
}


def _sort_blocks(blocks: list[list[int]]) {
    a: int = 1;
    n: int = len(blocks);
    while a < n {
        b: int = a;
        while b > 0 and _block_lt(blocks[b], blocks[b - 1]) {
            tmp: list[int] = blocks[b - 1];
            blocks[b - 1] = blocks[b];
            blocks[b] = tmp;
            b -= 1;
        }
        a += 1;
    }
}


def _ratio(a: str, b: str, autojunk: bool) -> float {
    blocks: list[list[int]] = _matching_blocks(a, b, autojunk);
    m: int = 0;
    idx: int = 0;
    while idx < len(blocks) {
        m += blocks[idx][2];
        idx += 1;
    }
    total: int = len(a) + len(b);
    if total == 0 {
        return 1.0;
    }
    return 2.0 * m / total;
}


obj:pub SequenceMatcher {
    has a: str = "",
        b: str = "",
        _isjunk: any = None,
        _autojunk: bool = True;

    def init(isjunk: any = None, a: str = "", b: str = "", autojunk: bool = True) {
        self._isjunk = isjunk;
        self.a = a;
        self.b = b;
        self._autojunk = autojunk;
    }

    def set_seq1(a: str) {
        self.a = a;
    }

    def set_seq2(b: str) {
        self.b = b;
    }

    def get_matching_blocks -> list[list[int]] {
        return _matching_blocks(self.a, self.b, self._autojunk);
    }

    def ratio -> float {
        return _ratio(self.a, self.b, self._autojunk);
    }
}


def _before(ra: float, wa: str, rb: float, wb: str) -> bool {
    if ra > rb {
        return True;
    }
    if ra < rb {
        return False;
    }
    return _str_gt(wa, wb);
}


def:pub get_close_matches(
    word: str, possibilities: list[str], n: int = 3, cutoff: float = 0.6
) -> list[str] {
    if n <= 0 {
        raise ValueError("n must be > 0: " + str(n));
    }
    if cutoff < 0.0 or cutoff > 1.0 {
        raise ValueError("cutoff must be in [0.0, 1.0]: " + str(cutoff));
    }
    words: list[str] = [];
    ratios: list[float] = [];
    pi: int = 0;
    pn: int = len(possibilities);
    while pi < pn {
        x: str = possibilities[pi];
        r: float = _ratio(x, word, True);
        if r >= cutoff {
            words.append(x);
            ratios.append(r);
        }
        pi += 1;
    }
    a: int = 1;
    an: int = len(words);
    while a < an {
        b: int = a;
        while b > 0 and _before(ratios[b], words[b], ratios[b - 1], words[b - 1]) {
            rt: float = ratios[b - 1];
            ratios[b - 1] = ratios[b];
            ratios[b] = rt;
            wt: str = words[b - 1];
            words[b - 1] = words[b];
            words[b] = wt;
            b -= 1;
        }
        a += 1;
    }
    result: list[str] = [];
    ri: int = 0;
    while ri < len(words) and ri < n {
        result.append(words[ri]);
        ri += 1;
    }
    return result;
}
