"""Semantic versions and ranges, ported from bun/src/semver
(Version.zig, SemverRange.zig, SemverQuery.zig) so that version selection
matches bun exactly — including its quirks (e.g. "1.0.0rc.1" parses as a
prerelease, wildcards from missing parts, `*` never matching prereleases).

Model:
  SemVer          major.minor.patch[-pre][+build]
  SemComparator   op + version  (op: unset | eql | lt | lte | gt | gte)
  SemRange        left AND right comparator (either may be unset)
  SemQuery        AND-chain of ranges          (bun: Query.next)
  SemGroup        OR-list of queries            (bun: Group / List.next)
"""

glob:pub SEMVER_MAX: int = 4611686018427387903,
     OP_UNSET: int = 0,
     OP_EQL: int = 1,
     OP_LT: int = 3,
     OP_LTE: int = 4,
     OP_GT: int = 5,
     OP_GTE: int = 6,
     WILD_NONE: int = 0,
     WILD_MAJOR: int = 1,
     WILD_MINOR: int = 2,
     WILD_PATCH: int = 3;  # stands in for u64 max in open-ended bounds

glob:priv _TAG_NONE: int = 0,
     _TAG_GT: int = 1,
     _TAG_GTE: int = 2,
     _TAG_LT: int = 3,
     _TAG_LTE: int = 4,
     _TAG_VERSION: int = 5,
     _TAG_TILDA: int = 6,
     _TAG_CARET: int = 7;

obj:pub SemVer {
    has major: int = 0,
        minor: int = 0,
        patch: int = 0,
        pre: str = "",
        build: str = "";
}

"""Result of parsing a (possibly partial) version: which parts were present,
the wildcard implied by missing/`x` parts, and how many bytes were consumed."""
obj:pub SemVerParse {
    has valid: bool = True,
        has_major: bool = False,
        has_minor: bool = False,
        has_patch: bool = False,
        ver: SemVer = SemVer(),
        wildcard: int = 0,
        consumed: int = 0;
}

obj:pub SemComparator {
    has op: int = 0,
        ver: SemVer = SemVer();
}

obj:pub SemRange {
    has left: SemComparator = SemComparator(),
        right: SemComparator = SemComparator();
}

obj:pub SemQuery {
    has ranges: list[SemRange] = [];
}

obj:pub SemGroup {
    has lists: list[SemQuery] = [],
        flag_pre: bool = False,
        flag_build: bool = False,
        input: str = "";
}

# ── helpers ───────────────────────────────────────────────────────────────────

def _is_digit(c: int) -> bool {
    return c >= 48 and c <= 57;
}
def _is_alpha(c: int) -> bool {
    return (c >= 97 and c <= 122) or (c >= 65 and c <= 90);
}
def _is_wild(c: int) -> bool {
    return c == 120 or c == 88 or c == 42;
}  # x X *

def:pub semver_copy(v: SemVer) -> SemVer {
    return SemVer(
        major=v.major, minor=v.minor, patch=v.patch, pre=v.pre, build=v.build
    );
}

def:pub semver_format(v: SemVer) -> str {
    s: str = str(v.major) + "." + str(v.minor) + "." + str(v.patch);
    if v.pre != "" {
        s = s + "-" + v.pre;
    }
    if v.build != "" {
        s = s + "+" + v.build;
    }
    return s;
}

"""Parse a version number field (digits only; 'x'/'X'/'*' → None, i.e. -1)."""
def _parse_number(s: str) -> int {
    if len(s) > 20 {
        return -1;
    }
    v: int = 0;
    n: int = 0;
    for ch in s {
        c: int = ord(ch);
        if _is_wild(c) {
            return -1;
        }
        if _is_digit(c) {
            v = v * 10 + (c - 48);
            n = n + 1;
            if n > 19 {
                return -1;
            }
        } elif c == 32 or c == 46 {
            break;
        }
        # other characters are ignored, as in bun
    }
    return v;
}

# ── tag parsing (prerelease / build) ──────────────────────────────────────────

"""bun's Tag.parseWithPreCount: returns (pre, build, consumed)."""
def:pub semver_tag_parse(input: str, initial_pre_count: int) -> tuple[str, str, int] {
    n: int = len(input);
    build_count: int = 0;
    pre_count: int = initial_pre_count;
    k: int = 0;
    while k < n {
        c: int = ord(input[k]);
        if c == 32 {
            break;
        }
        if c == 43 {
            build_count = build_count + 1;
        } elif c == 45 {
            pre_count = pre_count + 1;
        }
        k = k + 1;
    }
    if build_count == 0 and pre_count == 0 {
        return ("", "", 0);
    }
    pre: str = "";
    build: str = "";
    state: int = 0;  # 0 none, 1 pre, 2 build
    start: int = 0;
    i: int = 0;
    broke: bool = False;
    while i < n {
        c: int = ord(input[i]);
        if c == 43 {
            if state == 1 or (state == 0 and initial_pre_count > 0) {
                pre = input[start:i];
            }
            if state != 2 {
                state = 2;
                start = i + 1;
            }
        } elif c == 45 {
            if state != 1 {
                state = 1;
                start = i + 1;
            }
        } elif _is_alpha(c) or _is_digit(c) or c == 46 {
            # valid tag character
        } else {
            if state == 1 {
                pre = input[start:i];
                state = 0;
            } elif state == 2 {
                build = input[start:i];
                state = 0;
            }
            broke = True;
            break;
        }
        i = i + 1;
    }
    if broke {
        return (pre, build, i);
    }
    if state == 0 and initial_pre_count > 0 {
        state = 1;
        start = 0;
    }
    if state == 1 {
        pre = input[start:i];
    } elif state == 2 {
        build = input[start:i];
    }
    return (pre, build, i);
}

# ── version parsing ───────────────────────────────────────────────────────────

"""bun's Version.parse: lenient, partial-aware, reports the implied wildcard."""
def:pub semver_parse_version(input: str) -> SemVerParse {
    r: SemVerParse = SemVerParse();
    n: int = len(input);
    if n == 0 {
        r.valid = False;
        return r;
    }
    i: int = 0;
    # leading whitespace / 'v' / '='
    while i < n {
        c: int = ord(input[i]);
        if c == 32
            or c == 9
            or c == 10
            or c == 13
            or c == 11
            or c == 12
            or c == 118
            or c == 61 {
            i = i + 1;
        } else {
            break;
        }
    }
    if i >= n {
        r.valid = False;
        return r;
    }
    part_i: int = 0;
    is_done: bool = False;
    while i < n and not is_done {
        c: int = ord(input[i]);
        if c == 32 {
            is_done = True;
            break;
        }
        if c == 124 or c == 94 or c == 35 or c == 38 or c == 37 or c == 33 {  # | ^ # & % !
            is_done = True;
            if i > 0 {
                i = i - 1;
            }
            break;
        }
        if _is_digit(c) {
            start: int = i;
            i = i + 1;
            while i < n and _is_digit(ord(input[i])) {
                i = i + 1;
            }
            num: int = _parse_number(input[start:i]);
            if part_i == 0 {
                r.ver.major = num;
                r.has_major = num >= 0;
                part_i = 1;
            } elif part_i == 1 {
                r.ver.minor = num;
                r.has_minor = num >= 0;
                part_i = 2;
            } elif part_i == 2 {
                r.ver.patch = num;
                r.has_patch = num >= 0;
                part_i = 3;
            }
            if i < n and input[i] == "." and part_i != 3 {
                i = i + 1;
            }
            continue;
        }
        if c == 46 {  # '.'
            r.valid = False;
            is_done = True;
            break;
        }
        if c == 45 or c == 43 {  # '-' / '+'
            if part_i < 2 and r.wildcard == WILD_NONE {
                r.valid = False;
                is_done = True;
                break;
            }
            tg: tuple[str, str, int] = semver_tag_parse(input[i:], 0);
            r.ver.pre = tg[0];
            r.ver.build = tg[1];
            i = i + tg[2];
            break;
        }
        if _is_wild(c) {
            i = i + 1;
            while i < n and _is_wild(ord(input[i])) {
                i = i + 1;
            }
            if i < n and input[i] == "." {
                i = i + 1;
            }
            if r.wildcard == WILD_NONE {
                if part_i == 0 {
                    r.wildcard = WILD_MAJOR;
                    part_i = 1;
                } elif part_i == 1 {
                    r.wildcard = WILD_MINOR;
                    part_i = 2;
                } elif part_i == 2 {
                    r.wildcard = WILD_PATCH;
                    part_i = 3;
                }
            }
            continue;
        }
        # "1.0.0rc.1": letters right after the patch number are a prerelease
        if r.wildcard == WILD_NONE and part_i >= 2 and _is_alpha(c) {
            tg2: tuple[str, str, int] = semver_tag_parse(input[i:], 1);
            r.ver.pre = tg2[0];
            r.ver.build = tg2[1];
            i = i + tg2[2];
            is_done = True;
            break;
        }
        r.valid = False;
        is_done = True;
        break;
    }
    if r.wildcard == WILD_NONE {
        if part_i == 0 {
            r.wildcard = WILD_MAJOR;
        } elif part_i == 1 {
            r.wildcard = WILD_MINOR;
        } elif part_i == 2 {
            r.wildcard = WILD_PATCH;
        }
    }
    if r.ver.major < 0 {
        r.ver.major = 0;
        r.has_major = False;
    }
    if r.ver.minor < 0 {
        r.ver.minor = 0;
        r.has_minor = False;
    }
    if r.ver.patch < 0 {
        r.ver.patch = 0;
        r.has_patch = False;
    }
    r.consumed = i;
    return r;
}

"""Strict parse of a concrete version ("1.2.3", "v1.2.3-beta.1"): ok only when
all three numbers are present and nothing else follows."""
def:pub semver_parse_exact(input: str) -> tuple[bool, SemVer] {
    p: SemVerParse = semver_parse_version(input);
    if not p.valid
        or p.wildcard != WILD_NONE
        or not p.has_major
        or not p.has_minor
        or not p.has_patch {
        return (False, SemVer());
    }
    if p.consumed != len(input.strip()) and p.consumed != len(input) {
        return (False, SemVer());
    }
    return (True, p.ver);
}

# ── ordering ──────────────────────────────────────────────────────────────────

def _order_int(a: int, b: int) -> int {
    if a < b {
        return -1;
    }
    if a > b {
        return 1;
    }
    return 0;
}

def _order_str(a: str, b: str) -> int {
    if a < b {
        return -1;
    }
    if a > b {
        return 1;
    }
    return 0;
}

"""Compare two prerelease strings dot-part by dot-part: numeric parts compare
as numbers, a numeric part is less than a non-numeric one, otherwise bytes."""
def _order_pre(a: str, b: str) -> int {
    ap: list[str] = a.split(".");
    bp: list[str] = b.split(".");
    i: int = 0;
    while True {
        a_has: bool = i < len(ap);
        b_has: bool = i < len(bp);
        if not a_has and not b_has {
            return 0;
        }
        if not b_has {
            return 1;
        }
        if not a_has {
            return -1;
        }
        a_num: bool = ap[i] != "" and ap[i].isdigit();
        b_num: bool = bp[i] != "" and bp[i].isdigit();
        if a_num and not b_num {
            return -1;
        }
        if not a_num and b_num {
            return 1;
        }
        if a_num and b_num {
            o: int = _order_int(int(ap[i]), int(bp[i]));
            if o != 0 {
                return o;
            }
        } else {
            o2: int = _order_str(ap[i], bp[i]);
            if o2 != 0 {
                return o2;
            }
        }
        i = i + 1;
    }
}

def _order_tag_without_build(a: SemVer, b: SemVer) -> int {
    if a.pre != "" and b.pre != "" {
        return _order_pre(a.pre, b.pre);
    }
    return _order_str(a.pre, b.pre);
}

def _order_without_tag(a: SemVer, b: SemVer) -> int {
    if a.major != b.major {
        return _order_int(a.major, b.major);
    }
    if a.minor != b.minor {
        return _order_int(a.minor, b.minor);
    }
    if a.patch != b.patch {
        return _order_int(a.patch, b.patch);
    }
    if a.pre != "" {
        if b.pre == "" {
            return -1;
        }
    } elif b.pre != "" {
        return 1;
    }
    return 0;
}

"""Full order (build metadata breaks ties): -1 / 0 / 1."""
def:pub semver_order(a: SemVer, b: SemVer) -> int {
    o: int = _order_without_tag(a, b);
    if o != 0 {
        return o;
    }
    o = _order_tag_without_build(a, b);
    if o != 0 {
        return o;
    }
    return _order_str(a.build, b.build);
}

def:pub semver_order_without_build(a: SemVer, b: SemVer) -> int {
    o: int = _order_without_tag(a, b);
    if o != 0 {
        return o;
    }
    return _order_tag_without_build(a, b);
}

def:pub semver_eql(a: SemVer, b: SemVer) -> bool {
    return a.major == b.major
        and a.minor == b.minor
        and a.patch == b.patch
        and a.pre == b.pre
        and a.build == b.build;
}

"""Sort versions ascending (bun keeps manifests sorted this way)."""
def:pub semver_sort(vers: list[SemVer]) -> list[SemVer] {
    out: list[SemVer] = [];
    for v in vers {
        out.append(v);
    }
    i: int = 1;
    while i < len(out) {
        j: int = i;
        while j > 0 and semver_order(out[j - 1], out[j]) > 0 {
            tmp: SemVer = out[j - 1];
            out[j - 1] = out[j];
            out[j] = tmp;
            j = j - 1;
        }
        i = i + 1;
    }
    return out;
}

# ── ranges ────────────────────────────────────────────────────────────────────

def _cmp(op: int, v: SemVer) -> SemComparator {
    return SemComparator(op=op, ver=v);
}
def _v(major: int, minor: int, patch: int) -> SemVer {
    return SemVer(major=major, minor=minor, patch=patch);
}

def _has_left(r: SemRange) -> bool {
    return r.left.op != OP_UNSET;
}
def _has_right(r: SemRange) -> bool {
    return r.right.op != OP_UNSET;
}

"""`version.min()` of a partial: missing parts are 0."""
def _partial_min(p: SemVerParse) -> SemVer {
    return SemVer(
        major=p.ver.major,
        minor=p.ver.minor,
        patch=p.ver.patch,
        pre=p.ver.pre,
        build=p.ver.build
    );
}

"""bun's Range.initWildcard."""
def _init_wildcard(v: SemVer, wildcard: int) -> SemRange {
    if wildcard == WILD_MAJOR {
        return SemRange(left=_cmp(OP_GTE, _v(0, 0, 0)));
    }
    if wildcard == WILD_MINOR {
        return SemRange(
            left=_cmp(OP_LT, _v(v.major + 1, 0, 0)),
            right=_cmp(OP_GTE, _v(v.major, 0, 0))
        );
    }
    if wildcard == WILD_PATCH {
        return SemRange(
            left=_cmp(OP_LT, _v(v.major, v.minor + 1, 0)),
            right=_cmp(OP_GTE, _v(v.major, v.minor, 0))
        );
    }
    return SemRange(left=_cmp(OP_EQL, v));
}

"""bun's Token.toRange for a token tag + wildcard and a partial version."""
def _token_to_range(tag: int, wildcard: int, p: SemVerParse) -> SemRange {
    if tag == _TAG_CARET {
        r: SemRange = SemRange();
        if p.has_major {
            r.left = _cmp(OP_GTE, _v(p.ver.major, 0, 0));
            r.right = _cmp(OP_LT, _v(0, 0, 0));
            done: bool = False;
            if p.has_minor {
                r.left.ver.minor = p.ver.minor;
                if p.has_patch {
                    r.left.ver.patch = p.ver.patch;
                    r.left.ver.pre = p.ver.pre;
                    r.left.ver.build = p.ver.build;
                    if p.ver.major == 0 {
                        if p.ver.minor == 0 {
                            r.right.ver.patch = p.ver.patch + 1;
                        } else {
                            r.right.ver.minor = p.ver.minor + 1;
                        }
                        done = True;
                    }
                } elif p.ver.major == 0 {
                    r.right.ver.minor = p.ver.minor + 1;
                    done = True;
                }
            }
            if not done {
                r.right.ver.major = p.ver.major + 1;
            }
        }
        return r;
    }
    if tag == _TAG_TILDA {
        r2: SemRange = SemRange();
        if p.has_major {
            r2.left = _cmp(OP_GTE, _v(p.ver.major, 0, 0));
            r2.right = _cmp(OP_LT, _v(0, 0, 0));
            if p.has_minor {
                r2.left.ver.minor = p.ver.minor;
                if p.has_patch {
                    r2.left.ver.patch = p.ver.patch;
                    r2.left.ver.pre = p.ver.pre;
                    r2.left.ver.build = p.ver.build;
                }
                r2.right.ver.major = p.ver.major;
                r2.right.ver.minor = p.ver.minor + 1;
            } else {
                r2.right.ver.major = p.ver.major + 1;
            }
        }
        return r2;
    }
    if tag == _TAG_VERSION {
        if wildcard != WILD_NONE {
            return _init_wildcard(_partial_min(p), wildcard);
        }
        return SemRange(left=_cmp(OP_EQL, _partial_min(p)));
    }
    # comparison operators
    op: int = OP_UNSET;
    if tag == _TAG_GT {
        op = OP_GT;
    } elif tag == _TAG_GTE {
        op = OP_GTE;
    } elif tag == _TAG_LT {
        op = OP_LT;
    } elif tag == _TAG_LTE {
        op = OP_LTE;
    }
    major: int = p.ver.major;
    minor: int = p.ver.minor;
    if wildcard == WILD_MAJOR {
        return SemRange(
            left=_cmp(OP_GTE, _partial_min(p)),
            right=_cmp(OP_LTE, _v(SEMVER_MAX, SEMVER_MAX, SEMVER_MAX))
        );
    }
    if wildcard == WILD_MINOR {
        if tag == _TAG_LTE {
            return SemRange(left=_cmp(OP_LTE, _v(major, SEMVER_MAX, SEMVER_MAX)));
        }
        if tag == _TAG_LT {
            return SemRange(left=_cmp(OP_LT, _v(major, 0, 0)));
        }
        if tag == _TAG_GT {
            return SemRange(left=_cmp(OP_GT, _v(major, SEMVER_MAX, SEMVER_MAX)));
        }
        return SemRange(left=_cmp(OP_GTE, _v(major, 0, 0)));
    }
    if wildcard == WILD_PATCH {
        if tag == _TAG_LTE {
            return SemRange(left=_cmp(OP_LTE, _v(major, minor, SEMVER_MAX)));
        }
        if tag == _TAG_LT {
            return SemRange(left=_cmp(OP_LT, _v(major, minor, 0)));
        }
        if tag == _TAG_GT {
            return SemRange(left=_cmp(OP_GT, _v(major, minor, SEMVER_MAX)));
        }
        return SemRange(left=_cmp(OP_GTE, _v(major, minor, 0)));
    }
    return SemRange(left=_cmp(op, _partial_min(p)));
}

def _group_last_list(g: SemGroup) -> SemQuery {
    if len(g.lists) == 0 {
        g.lists.append(SemQuery());
    }
    return g.lists[len(g.lists) - 1];
}

"""bun's List.andRange on the group's tail list."""
def _group_and_range(g: SemGroup, r: SemRange) -> None {
    q: SemQuery = _group_last_list(g);
    if len(q.ranges) == 0 {
        q.ranges.append(r);
        return;
    }
    head: SemRange = q.ranges[0];
    if len(q.ranges) == 1 and not _has_left(head) and not _has_right(head) {
        q.ranges[0] = r;
        return;
    }
    q.ranges.append(r);
}

"""bun's Group.orRange."""
def _group_or_range(g: SemGroup, r: SemRange) -> None {
    if len(g.lists) == 1 and len(g.lists[0].ranges) <= 1 {
        if len(g.lists[0].ranges) == 0 {
            g.lists[0].ranges.append(r);
            return;
        }
        if not _has_left(g.lists[0].ranges[0]) {
            g.lists[0].ranges[0] = r;
            return;
        }
    }
    if len(g.lists) == 0 {
        g.lists.append(SemQuery(ranges=[r]));
        return;
    }
    g.lists.append(SemQuery(ranges=[r]));
}

"""bun's Group.orVersion."""
def _group_or_version(g: SemGroup, v: SemVer) -> None {
    if len(g.lists) == 1 and len(g.lists[0].ranges) <= 1 {
        if len(g.lists[0].ranges) == 0 {
            g.lists[0].ranges.append(SemRange(left=_cmp(OP_EQL, v)));
            return;
        }
        if not _has_left(g.lists[0].ranges[0]) {
            g.lists[0].ranges[0].left = _cmp(OP_EQL, v);
            return;
        }
    }
    if len(g.lists) == 0 {
        g.lists.append(SemQuery(ranges=[SemRange(left=_cmp(OP_EQL, v))]));
        return;
    }
    g.lists.append(SemQuery(ranges=[SemRange(left=_cmp(OP_EQL, v))]));
}

def _skip_spaces(input: str, i: int) -> int {
    n: int = len(input);
    while i < n and input[i] == " " {
        i = i + 1;
    }
    return i;
}

def _leading_ws(input: str, i: int) -> int {
    n: int = len(input);
    while i < n {
        c: int = ord(input[i]);
        if c == 32 or c == 9 or c == 10 or c == 13 or c == 11 or c == 12 {
            i = i + 1;
        } else {
            break;
        }
    }
    return i;
}

"""bun's Query.parse: the npm range grammar (`^1.2`, `~1`, `>=1 <2`, `1.x`,
`1.0.0 - 2.0.0`, `a || b`, `*`, `latest`-style tags ignored)."""
def:pub semver_parse_range(input: str) -> SemGroup {
    g: SemGroup = SemGroup(input=input);
    g.lists.append(SemQuery(ranges=[SemRange()]));
    n: int = len(input);
    i: int = 0;
    tag: int = _TAG_NONE;
    wildcard: int = WILD_NONE;
    count: int = 0;
    is_or: bool = False;
    while i < n {
        skip_round: bool = False;
        c: int = ord(input[i]);
        if c == 62 {  # '>'
            if i + 1 < n and input[i + 1] == "=" {
                tag = _TAG_GTE;
                i = i + 1;
            } else {
                tag = _TAG_GT;
            }
            i = _skip_spaces(input, i + 1);
        } elif c == 60 {  # '<'
            if i + 1 < n and input[i + 1] == "=" {
                tag = _TAG_LTE;
                i = i + 1;
            } else {
                tag = _TAG_LT;
            }
            i = _skip_spaces(input, i + 1);
        } elif c == 61 or c == 118 {  # '=' 'v'
            tag = _TAG_VERSION;
            is_or = True;
            i = _skip_spaces(input, i + 1);
        } elif c == 126 {  # '~'
            tag = _TAG_TILDA;
            i = i + 1;
            if i < n and input[i] == ">" {
                i = i + 1;
            }
            i = _skip_spaces(input, i);
        } elif c == 94 {  # '^'
            tag = _TAG_CARET;
            i = _skip_spaces(input, i + 1);
        } elif _is_digit(c) or _is_wild(c) {
            tag = _TAG_VERSION;
            is_or = True;
        } elif c == 124 {  # '|'
            i = i + 1;
            while i < n and input[i] == "|" {
                i = i + 1;
            }
            i = _skip_spaces(input, i);
            is_or = True;
            tag = _TAG_NONE;
            skip_round = True;
        } elif c == 45 {  # '-'
            i = _skip_spaces(input, i + 1);
        } elif c == 32 {
            i = _skip_spaces(input, i + 1);
            skip_round = True;
        } else {
            i = i + 1;
            tag = _TAG_NONE;
            while i < n and input[i] != " " and input[i] != "|" {
                i = i + 1;
            }
            skip_round = True;
        }
        if skip_round {
            continue;
        }

        p: SemVerParse = semver_parse_version(input[i:]);
        version: SemVer = _partial_min(p);
        if version.build != "" {
            g.flag_build = True;
        }
        if version.pre != "" {
            g.flag_pre = True;
        }
        wildcard = p.wildcard;
        i = i + p.consumed;
        rollback: int = i;
        maybe_hyphenate: bool = i < n and (input[i] == " " or input[i] == "-");
        hyphenate: bool = False;
        if maybe_hyphenate {
            j: int = _leading_ws(input, i);
            ok: bool = j < n and input[j] == "-";
            if ok {
                j = _leading_ws(input, j + 1);
                if j >= n {
                    ok = False;
                }
            }
            if ok {
                if input[j] == "v" or input[j] == "=" {
                    j = j + 1;
                }
                if j >= n {
                    ok = False;
                }
            }
            if ok {
                j = _leading_ws(input, j);
                if j >= n {
                    ok = False;
                }
            }
            if ok {
                cj: int = ord(input[j]);
                if not (_is_digit(cj) or _is_wild(cj)) {
                    ok = False;
                }
            }
            if ok {
                hyphenate = True;
                i = j;
            }
        }
        if not hyphenate {
            i = rollback + 1;
        }
        if hyphenate {
            second: SemVerParse = semver_parse_version(input[i:]);
            sv: SemVer = _partial_min(second);
            if sv.build != "" {
                g.flag_build = True;
            }
            if sv.pre != "" {
                g.flag_pre = True;
            }
            r: SemRange = SemRange();
            if second.wildcard == WILD_MAJOR {
                r = SemRange(left=_cmp(OP_GTE, version));
            } elif second.wildcard == WILD_MINOR {
                r = SemRange(
                    left=_cmp(OP_GTE, version),
                    right=_cmp(OP_LT, _v(sv.major + 1, 0, 0))
                );
            } elif second.wildcard == WILD_PATCH {
                r = SemRange(
                    left=_cmp(OP_GTE, version),
                    right=_cmp(OP_LT, _v(sv.major, sv.minor + 1, 0))
                );
            } else {
                r = SemRange(left=_cmp(OP_GTE, version), right=_cmp(OP_LTE, sv));
            }
            if is_or {
                _group_or_range(g, r);
            } else {
                _group_and_range(g, r);
            }
            i = i + second.consumed + 1;
        } elif count == 0 and tag == _TAG_VERSION {
            if wildcard == WILD_NONE {
                _group_or_version(g, version);
            } else {
                _group_or_range(g, _token_to_range(tag, wildcard, p));
            }
        } elif count == 0 {
            if tag == _TAG_NONE {
                is_or = False;
                wildcard = WILD_NONE;
                continue;
            }
            _group_and_range(g, _token_to_range(tag, wildcard, p));
        } elif is_or {
            _group_or_range(g, _token_to_range(tag, wildcard, p));
        } else {
            _group_and_range(g, _token_to_range(tag, wildcard, p));
        }
        is_or = False;
        count = count + 1;
        wildcard = WILD_NONE;
    }
    return g;
}

# ── satisfaction ──────────────────────────────────────────────────────────────

def _comparator_satisfies(c: SemComparator, v: SemVer) -> bool {
    o: int = semver_order_without_build(v, c.ver);
    if o == 0 {
        return c.op == OP_LTE or c.op == OP_GTE or c.op == OP_EQL;
    }
    if o > 0 {
        return c.op == OP_GT or c.op == OP_GTE;
    }
    return c.op == OP_LT or c.op == OP_LTE;
}

def _range_satisfies(r: SemRange, v: SemVer) -> bool {
    if not _has_left(r) {
        return True;
    }
    if not _comparator_satisfies(r.left, v) {
        return False;
    }
    if _has_right(r) and not _comparator_satisfies(r.right, v) {
        return False;
    }
    return True;
}

def _same_core(a: SemVer, b: SemVer) -> bool {
    return a.major == b.major and a.minor == b.minor and a.patch == b.patch;
}

"""Range.satisfiesPre: also records whether the prerelease version shares
major.minor.patch with a prerelease comparator (npm's rule for prereleases)."""
def _range_satisfies_pre(r: SemRange, v: SemVer, pre_matched: list[bool]) -> bool {
    if not _has_left(r) {
        return True;
    }
    if (r.left.ver.pre != "" and _same_core(v, r.left.ver))
        or (_has_right(r) and r.right.ver.pre != "" and _same_core(v, r.right.ver)) {
        pre_matched[0] = True;
    }
    if not _comparator_satisfies(r.left, v) {
        return False;
    }
    if _has_right(r) and not _comparator_satisfies(r.right, v) {
        return False;
    }
    return True;
}

def _query_satisfies(q: SemQuery, v: SemVer) -> bool {
    for r in q.ranges {
        if not _range_satisfies(r, v) {
            return False;
        }
    }
    return True;
}

def _query_satisfies_pre(q: SemQuery, v: SemVer, pre_matched: list[bool]) -> bool {
    for r in q.ranges {
        if not _range_satisfies_pre(r, v, pre_matched) {
            return False;
        }
    }
    return True;
}

"""Does `v` satisfy the range group? Prerelease versions only match when a
comparator with the same major.minor.patch carries a prerelease itself."""
def:pub semver_satisfies(g: SemGroup, v: SemVer) -> bool {
    if v.pre != "" {
        for q in g.lists {
            pm: list[bool] = [False];
            if _query_satisfies_pre(q, v, pm) and pm[0] {
                return True;
            }
        }
        return False;
    }
    for q in g.lists {
        if _query_satisfies(q, v) {
            return True;
        }
    }
    return False;
}

"""True when the group is a single exact version (`1.2.3`)."""
def:pub semver_group_is_exact(g: SemGroup) -> bool {
    if len(g.lists) != 1 or len(g.lists[0].ranges) != 1 {
        return False;
    }
    r: SemRange = g.lists[0].ranges[0];
    return r.left.op == OP_EQL and not _has_right(r);
}

"""The exact version of an exact group."""
def:pub semver_group_exact_version(g: SemGroup) -> SemVer {
    return g.lists[0].ranges[0].left.ver;
}

"""`*` / `>=0.0.0`: bun's Range.anyRangeSatisfies on the first range."""
def:pub semver_group_is_any(g: SemGroup) -> bool {
    if len(g.lists) == 0 or len(g.lists[0].ranges) == 0 {
        return True;
    }
    r: SemRange = g.lists[0].ranges[0];
    if not _has_left(r) {
        return True;
    }
    return r.left.op == OP_GTE and semver_eql(r.left.ver, SemVer());
}

def _fmt_cmp(c: SemComparator) -> str {
    ops: dict[int, str] = {1: "==", 3: "<", 4: "<=", 5: ">", 6: ">="};
    return ops[c.op] + semver_format(c.ver);
}

"""Debug rendering: ranges joined by " " (AND), lists by " || "."""
def:pub semver_group_format(g: SemGroup) -> str {
    parts: list[str] = [];
    for q in g.lists {
        rs: list[str] = [];
        for r in q.ranges {
            if not _has_left(r) {
                rs.append("*");
                continue;
            }
            s: str = _fmt_cmp(r.left);
            if _has_right(r) {
                s = s + " " + _fmt_cmp(r.right);
            }
            rs.append(s);
        }
        parts.append(" ".join(rs));
    }
    return " || ".join(parts);
}
