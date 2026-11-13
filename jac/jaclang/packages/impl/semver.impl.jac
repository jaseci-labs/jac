impl Version.parse(text: str) -> Version {
    m = VERSION_RE.`match(text.strip());
    if not m {
        raise SemverError(f"'{text}' is not a semantic version (MAJOR.MINOR.PATCH)");
    }
    pre: list[int | str] = [];
    if m.group(4) {
        for ident in m.group(4).split(".") {
            pre.append(int(ident) if ident.isdigit() else ident);
        }
    }
    return Version(
        major=int(m.group(1)),
        minor=int(m.group(2)),
        patch=int(m.group(3)),
        pre=tuple(pre),
        build=m.group(5) or ""
    );
}

impl Version.lowest(major: int, minor: int, patch: int) -> Version {
    return Version(major=major, minor=minor, patch=patch, pre=(0, ));
}

impl Version.key -> tuple[int, int, int, int, tuple[tuple[int, int, str], ...]] {
    pre_key = tuple(
        [(0, p, "") if isinstance(p, int) else (1, 0, p) for p in self.pre]
    );
    return (self.major, self.minor, self.patch, 0 if self.pre else 1, pre_key);
}

impl Version.is_prerelease -> bool {
    return bool(self.pre);
}

impl Version.release -> Version {
    return Version(major=self.major, minor=self.minor, patch=self.patch);
}

impl Version.bump_major -> Version {
    return Version(major=self.major + 1, minor=0, patch=0);
}

impl Version.bump_minor -> Version {
    return Version(major=self.major, minor=self.minor + 1, patch=0);
}

impl Version.bump_patch -> Version {
    return Version(major=self.major, minor=self.minor, patch=self.patch + 1);
}

impl Version.__str__ -> str {
    text = f"{self.major}.{self.minor}.{self.patch}";
    if self.pre {
        text += "-" + ".".join([str(p) for p in self.pre]);
    }
    if self.build {
        text += "+" + self.build;
    }
    return text;
}

impl Version.__eq__(other: object) -> bool {
    return isinstance(other, Version) and self.key() == other.key();
}

impl Version.__hash__ -> int {
    return hash(self.key());
}

impl Version.__lt__(other: Version) -> bool {
    return self.key() < other.key();
}

impl Version.__le__(other: Version) -> bool {
    return self.key() <= other.key();
}

impl Version.__gt__(other: Version) -> bool {
    return self.key() > other.key();
}

impl Version.__ge__(other: Version) -> bool {
    return self.key() >= other.key();
}

impl Interval.contains(v: Version) -> bool {
    if self.lo.version is not None {
        if v < self.lo.version or (v == self.lo.version and not self.lo.inclusive) {
            return False;
        }
    }
    if self.hi.version is not None {
        if v > self.hi.version or (v == self.hi.version and not self.hi.inclusive) {
            return False;
        }
    }
    return True;
}

impl Interval.is_empty -> bool {
    if self.lo.version is None or self.hi.version is None {
        return False;
    }
    if self.lo.version > self.hi.version {
        return True;
    }
    if self.lo.version == self.hi.version {
        return not (self.lo.inclusive and self.hi.inclusive);
    }
    return False;
}

impl _lo_key(
    b: Bound
) -> tuple[int, tuple[int, int, int, int, tuple[tuple[int, int, str], ...]], int] {
    if b.version is None {
        return (0, NO_KEY, 0);
    }
    return (1, b.version.key(), 0 if b.inclusive else 1);
}

impl _hi_key(
    b: Bound
) -> tuple[int, tuple[int, int, int, int, tuple[tuple[int, int, str], ...]], int] {
    if b.version is None {
        return (2, NO_KEY, 0);
    }
    return (1, b.version.key(), 1 if b.inclusive else 0);
}

impl _max_lo(a: Bound, b: Bound) -> Bound {
    return a if _lo_key(a) >= _lo_key(b) else b;
}

impl _min_hi(a: Bound, b: Bound) -> Bound {
    return a if _hi_key(a) <= _hi_key(b) else b;
}

impl _touches(left: Interval, right: Interval) -> bool {
    if left.hi.version is None or right.lo.version is None {
        return True;
    }
    if left.hi.version > right.lo.version {
        return True;
    }
    if left.hi.version == right.lo.version {
        return left.hi.inclusive or right.lo.inclusive;
    }
    return False;
}

impl VersionSet.any_version -> VersionSet {
    return VersionSet(intervals=[Interval()]);
}

impl VersionSet.none -> VersionSet {
    return VersionSet(intervals=[]);
}

impl VersionSet.exact(v: Version) -> VersionSet {
    return VersionSet(
        intervals=[
            Interval(
                lo=Bound(version=v, inclusive=True), hi=Bound(version=v, inclusive=True)
            )
        ]
    );
}

impl VersionSet.between(lo: Version | None, hi: Version | None) -> VersionSet {
    return VersionSet(
        intervals=[
            Interval(
                lo=Bound(version=lo, inclusive=True) if lo is not None else Bound(),
                hi=Bound(version=hi, inclusive=False) if hi is not None else Bound()
            )
        ]
    );
}

impl VersionSet.normalized(items: list[Interval]) -> VersionSet {
    live = [
        iv
        for iv in items
        if not iv.is_empty()
    ];
    live.sort(key=lambda (iv: Interval) { _lo_key(iv.lo); });
    merged: list[Interval] = [];
    for iv in live {
        if merged and _touches(merged[-1], iv) {
            last = merged[-1];
            hi = last.hi if _hi_key(last.hi) >= _hi_key(iv.hi) else iv.hi;
            merged[-1] = Interval(lo=last.lo, hi=hi);
        } else {
            merged.append(iv);
        }
    }
    return VersionSet(intervals=merged);
}

impl VersionSet.is_empty -> bool {
    return not self.intervals;
}

impl VersionSet.is_any -> bool {
    return len(self.intervals) == 1
        and self.intervals[0].lo.version is None
        and self.intervals[0].hi.version is None;
}

impl VersionSet.contains(v: Version) -> bool {
    return any(iv.contains(v) for iv in self.intervals);
}

impl VersionSet.intersect(other: VersionSet) -> VersionSet {
    out: list[Interval] = [];
    for a in self.intervals {
        for b in other.intervals {
            iv = Interval(lo=_max_lo(a.lo, b.lo), hi=_min_hi(a.hi, b.hi));
            if not iv.is_empty() {
                out.append(iv);
            }
        }
    }
    return VersionSet.normalized(out);
}

impl VersionSet.union(other: VersionSet) -> VersionSet {
    return VersionSet.normalized(self.intervals + other.intervals);
}

impl VersionSet.complement -> VersionSet {
    out: list[Interval] = [];
    cursor = Bound();
    for iv in self.intervals {
        if iv.lo.version is not None {
            out.append(
                Interval(
                    lo=cursor,
                    hi=Bound(version=iv.lo.version, inclusive=not iv.lo.inclusive)
                )
            );
        }
        if iv.hi.version is None {
            return VersionSet.normalized(out);
        }
        cursor = Bound(version=iv.hi.version, inclusive=not iv.hi.inclusive);
    }
    out.append(Interval(lo=cursor, hi=Bound()));
    return VersionSet.normalized(out);
}

impl VersionSet.difference(other: VersionSet) -> VersionSet {
    return self.intersect(other.complement());
}

impl VersionSet.subset_of(other: VersionSet) -> bool {
    return self.difference(other).is_empty();
}

impl VersionSet.disjoint(other: VersionSet) -> bool {
    return self.intersect(other).is_empty();
}

impl VersionSet.same_as(other: VersionSet) -> bool {
    return self.subset_of(other) and other.subset_of(self);
}

impl VersionSet.__str__ -> str {
    if self.is_empty() {
        return "no versions";
    }
    if self.is_any() {
        return "any version";
    }
    parts: list[str] = [];
    for iv in self.intervals {
        if iv.lo.version is not None
            and iv.hi.version is not None
            and iv.lo.version == iv.hi.version {
            parts.append(str(iv.lo.version));
            continue;
        }
        bits: list[str] = [];
        if iv.lo.version is not None {
            bits.append((">=" if iv.lo.inclusive else ">") + str(iv.lo.version));
        }
        if iv.hi.version is not None {
            bits.append(("<=" if iv.hi.inclusive else "<") + str(iv.hi.version));
        }
        parts.append(", ".join(bits));
    }
    return " || ".join(parts);
}

impl _partial(text: str) -> tuple[list[int | None], tuple[int | str, ...]] {
    m = PARTIAL_RE.`match(text.strip());
    if not m {
        raise SemverError(f"'{text}' is not a version or version prefix");
    }
    parts: list[int | None] = [];
    wild = False;
    for g in (m.group(1), m.group(2), m.group(3)) {
        if g is None or g in ("*", "x", "X") or wild {
            wild = wild or (g is not None);
            parts.append(None);
        } else {
            parts.append(int(g));
        }
    }
    pre: tuple[int | str, ...] = ();
    if m.group(4) {
        if None in parts {
            raise SemverError(f"'{text}': a pre-release needs a full version");
        }
        pre = Version.parse(text.strip()).pre;
    }
    return (parts, pre);
}

impl _floor(parts: list[int | None], pre: tuple[int | str, ...]) -> Version {
    return Version(
        major=parts[0] or 0, minor=parts[1] or 0, patch=parts[2] or 0, pre=pre
    );
}

impl _caret(parts: list[int | None], pre: tuple[int | str, ...]) -> VersionSet {
    lo = _floor(parts, pre);
    (major, minor, patch) = (parts[0], parts[1], parts[2]);
    if major is None {
        return VersionSet.any_version();
    }
    if major > 0 or minor is None {
        hi = Version.lowest(major + 1, 0, 0);
    } elif minor > 0 or patch is None {
        hi = Version.lowest(0, minor + 1, 0);
    } else {
        hi = Version.lowest(0, 0, patch + 1);
    }
    return VersionSet.between(lo, hi);
}

impl _tilde(parts: list[int | None], pre: tuple[int | str, ...]) -> VersionSet {
    lo = _floor(parts, pre);
    (major, minor) = (parts[0], parts[1]);
    if major is None {
        return VersionSet.any_version();
    }
    if minor is None {
        return VersionSet.between(lo, Version.lowest(major + 1, 0, 0));
    }
    return VersionSet.between(lo, Version.lowest(major, minor + 1, 0));
}

impl _next_after(parts: list[int | None]) -> Version {
    (major, minor, patch) = (parts[0], parts[1], parts[2]);
    if minor is None {
        return Version.lowest((major or 0) + 1, 0, 0);
    }
    if patch is None {
        return Version.lowest(major or 0, minor + 1, 0);
    }
    return Version.lowest(major or 0, minor, patch + 1);
}

impl _comparator(op: str, operand: str) -> VersionSet {
    (parts, pre) = _partial(operand);
    if parts[0] is None {
        return VersionSet.any_version();
    }
    exact = None not in parts;
    if op == "" and re.search(r"[*xX]", operand) {
        op = "=";
    }
    if op in ("", "^") {
        return _caret(parts, pre);
    }
    if op == "~" {
        return _tilde(parts, pre);
    }
    if op in ("=", "==") {
        if exact {
            return VersionSet.exact(_floor(parts, pre));
        }
        return VersionSet.between(_floor(parts, pre), _next_after(parts));
    }
    if op == ">=" {
        return VersionSet.between(_floor(parts, pre), None);
    }
    if op == ">" {
        if exact {
            return VersionSet(
                intervals=[
                    Interval(lo=Bound(version=_floor(parts, pre), inclusive=False))
                ]
            );
        }
        return VersionSet.between(_next_after(parts), None);
    }
    if op == "<" {
        return VersionSet.between(None, _floor(parts, pre or (0, )));
    }
    if op == "<=" {
        if exact {
            return VersionSet(
                intervals=[
                    Interval(hi=Bound(version=_floor(parts, pre), inclusive=True))
                ]
            );
        }
        return VersionSet.between(None, _next_after(parts));
    }
    raise SemverError(f"unknown version operator '{op}'");
}

impl Requirement.parse(text: str) -> Requirement {
    raw = (text or "").strip();
    if raw in ("", "*") {
        return Requirement(text="*", versions=VersionSet.any_version());
    }
    total = VersionSet.none();
    names_pre = False;
    for alternative in raw.split("||") {
        clause = VersionSet.any_version();
        pieces = [
            p.strip()
            for p in alternative.split(",")
            if p.strip()
        ];
        if not pieces {
            raise SemverError(f"'{text}': empty version clause");
        }
        for piece in pieces {
            m = COMPARATOR_RE.`match(piece);
            if not m {
                raise SemverError(f"'{piece}' is not a version requirement");
            }
            operand = m.group(2).strip();
            if "-" in operand {
                names_pre = True;
            }
            clause = clause.intersect(_comparator(m.group(1) or "", operand));
        }
        total = total.union(clause);
    }
    return Requirement(text=raw, versions=total, names_prerelease=names_pre);
}

impl Requirement.matches(v: Version) -> bool {
    if v.is_prerelease() and not self.names_prerelease {
        return False;
    }
    return self.versions.contains(v);
}

impl caret_for(v: Version) -> str {
    return f"^{v.release()}";
}
