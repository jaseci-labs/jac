def _class_end(pat: str, start: int) -> int {
    n: int = len(pat);
    j: int = start + 1;
    if j < n and pat[j] == "!" {
        j += 1;
    }
    if j < n and pat[j] == "]" {
        j += 1;
    }
    while j < n and pat[j] != "]" {
        j += 1;
    }
    if j >= n {
        return -1;
    }
    return j;
}

def _class_hit(pat: str, start: int, close: int, ch: str) -> bool {
    j: int = start + 1;
    neg: bool = False;
    if j < close and pat[j] == "!" {
        neg = True;
        j += 1;
    }
    hit: bool = False;
    c: int = ord(ch);
    while j < close {
        if j + 2 < close and pat[j + 1] == "-" {
            if ord(pat[j]) <= c and c <= ord(pat[j + 2]) {
                hit = True;
            }
            j += 3;
            continue;
        }
        if pat[j] == ch {
            hit = True;
        }
        j += 1;
    }
    if neg {
        return not hit;
    }
    return hit;
}

def _match(name: str, pat: str) -> bool {
    n: int = len(name);
    m: int = len(pat);
    i: int = 0;
    j: int = 0;
    star_j: int = -1;
    star_i: int = 0;
    while i < n {
        matched: bool = False;
        nj: int = j;
        if j < m {
            pc: str = pat[j];
            if pc == "*" {
                star_j = j;
                star_i = i;
                j += 1;
                continue;
            }
            if pc == "?" {
                matched = True;
                nj = j + 1;
            } elif pc == "[" {
                close: int = _class_end(pat, j);
                if close < 0 {
                    matched = name[i] == "[";
                    nj = j + 1;
                } else {
                    matched = _class_hit(pat, j, close, name[i]);
                    nj = close + 1;
                }
            } else {
                matched = name[i] == pc;
                nj = j + 1;
            }
        }
        if matched {
            i += 1;
            j = nj;
            continue;
        }
        if star_j >= 0 {
            star_i += 1;
            i = star_i;
            j = star_j + 1;
            continue;
        }
        return False;
    }
    while j < m and pat[j] == "*" {
        j += 1;
    }
    return j == m;
}

def:pub normcase(s: str) -> str {
    return s;
}

def:pub fnmatchcase(name: str, pat: str) -> bool {
    return _match(name, pat);
}

def:pub fnmatch(name: str, pat: str) -> bool {
    return _match(normcase(name), normcase(pat));
}
