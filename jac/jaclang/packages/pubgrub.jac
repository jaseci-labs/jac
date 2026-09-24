import from enum { StrEnum }
import from jaclang.packages.semver { Requirement, Version, VersionSet }

enum CauseKind(StrEnum) {
    ROOT = "root_name",
    DEPENDENCY = "dependency",
    NO_VERSIONS = "no_versions",
    UNAVAILABLE = "unavailable",
    DERIVED = "derived"
}

obj Term {
    has package: str,
        versions: VersionSet,
        positive: bool = True;

    def negate -> Term {
        return Term(
            package=self.package, versions=self.versions, positive=not self.positive
        );
    }

    def satisfies(other: Term) -> bool {
        if self.positive and other.positive {
            return self.versions.subset_of(other.versions);
        }
        if self.positive and not other.positive {
            return self.versions.disjoint(other.versions);
        }
        if not self.positive and other.positive {
            return False;
        }
        return other.versions.subset_of(self.versions);
    }

    def is_disjoint(other: Term) -> bool {
        if self.positive and other.positive {
            return self.versions.disjoint(other.versions);
        }
        if self.positive and not other.positive {
            return self.versions.subset_of(other.versions);
        }
        if not self.positive and other.positive {
            return other.versions.subset_of(self.versions);
        }
        return False;
    }

    def intersect(other: Term) -> Term {
        if self.positive and other.positive {
            return Term(
                package=self.package, versions=self.versions.intersect(other.versions)
            );
        }
        if self.positive {
            return Term(
                package=self.package, versions=self.versions.difference(other.versions)
            );
        }
        if other.positive {
            return Term(
                package=self.package, versions=other.versions.difference(self.versions)
            );
        }
        return Term(
            package=self.package,
            versions=self.versions.union(other.versions),
            positive=False
        );
    }

    def difference(other: Term) -> Term {
        return self.intersect(other.negate());
    }

    def is_empty -> bool {
        return self.positive and self.versions.is_empty();
    }

    def describe -> str {
        return self.package
            if self.versions.is_any()
            else f"{self.package} {self.versions}";
    }
}

obj Incompatibility {
    has terms: dict[str, Term],
        kind: CauseKind,
        left: Incompatibility | None = None,
        right: Incompatibility | None = None,
        note: str = "";

    static def of(
        terms: list[Term],
        kind: CauseKind,
        left: Incompatibility | None = None,
        right: Incompatibility | None = None,
        note: str = ""
    ) -> Incompatibility {
        merged: dict[str, Term] = {};
        for t in terms {
            if t.package in merged {
                merged[t.package] = merged[t.package].intersect(t);
            } else {
                merged[t.package] = t;
            }
        }
        return Incompatibility(
            terms=merged, kind=kind, left=left, right=right, note=note
        );
    }

    def is_failure(root_name: str) -> bool {
        if not self.terms {
            return True;
        }
        if len(self.terms) == 1 {
            only = next(iter(self.terms.values()));
            return only.package == root_name and only.positive;
        }
        return False;
    }

    def describe(root_name: str) -> str {
        if self.kind == CauseKind.ROOT {
            return f"{root_name} is the project being resolved";
        }
        terms = list(self.terms.values());
        if self.kind == CauseKind.DEPENDENCY and len(terms) == 2 {
            depender = terms[0] if terms[0].positive else terms[1];
            dependee = terms[1] if terms[0].positive else terms[0];
            return f"{_subject(depender, root_name)} depends on {dependee.describe()}";
        }
        if self.kind == CauseKind.NO_VERSIONS and terms {
            return f"no versions of {terms[0].describe()} are available";
        }
        if self.kind == CauseKind.UNAVAILABLE and terms {
            return f"{terms[0].describe()} is unavailable ({self.note})";
        }
        positive = [
            t
            for t in terms
            if t.positive
        ];
        negative = [
            t
            for t in terms
            if not t.positive
        ];
        if not terms {
            return "version solving failed";
        }
        if len(positive) == 1 and not negative {
            return f"{_subject(positive[0], root_name)} is forbidden";
        }
        if len(positive) == 1 and len(negative) == 1 {
            return f"{_subject(positive[0], root_name)} requires {negative[
                0
            ].describe()}";
        }
        if len(positive) == 2 and not negative {
            return (
                f"{_subject(positive[0], root_name)} is incompatible with "
                f"{_subject(positive[1], root_name)}"
            );
        }
        if not positive {
            return "one of "
                + ", ".join([t.describe() for t in negative])
                + " must be used";
        }
        return "these versions cannot be used together: "
            + ", ".join([t.describe() for t in positive]);
    }
}

def _subject(t: Term, root_name: str) -> str {
    return "the project" if t.package == root_name else t.describe();
}

obj Assignment {
    has term: Term,
        level: int,
        cause: Incompatibility | None = None;

    def is_decision -> bool {
        return self.cause is None;
    }
}

obj SolveFailure(Exception) {
    has incompatibility: Incompatibility,
        root_name: str;

    def postinit {
        Exception.__init__(self, explain(self.incompatibility, self.root_name));
    }
}

obj PackageSource {
    def versions(name: str) -> list[Version] abst;
    def dependencies(name: str, version: Version) -> dict[str, Requirement] abst;
    def unavailable_reason(name: str, version: Version) -> str abst;
    def preferred(name: str) -> Version | None abst;
    def allows_prerelease(name: str) -> bool abst;
}

obj Solver {
    has source: PackageSource,
        root_name: str,
        root_version: Version,
        incompatibilities: dict[str, list[Incompatibility]] = {},
        assignments: list[Assignment] = [],
        decisions: dict[str, Version] = {},
        level: int = 0,
        _candidates: dict[str, list[Version]] = {};

    def solve -> dict[str, Version] {
        self._add(
            Incompatibility.of(
                [
                    Term(
                        package=self.root_name,
                        versions=VersionSet.exact(self.root_version),
                        positive=False
                    )
                ],
                CauseKind.ROOT
            )
        );
        nxt: str | None = self.root_name;
        while nxt is not None {
            self._propagate(nxt);
            nxt = self._decide();
        }
        return {
            name: v
            for (name, v) in self.decisions.items()
            if name != self.root_name
        };
    }

    def _add(incompat: Incompatibility) {
        for name in incompat.terms {
            self.incompatibilities.setdefault(name, []).append(incompat);
        }
    }

    def _accumulated(name: str) -> Term | None {
        acc: Term | None = None;
        for a in self.assignments {
            if a.term.package == name {
                acc = a.term if acc is None else acc.intersect(a.term);
            }
        }
        return acc;
    }

    def _relation(incompat: Incompatibility) -> tuple[str, Term | None] {
        unresolved: Term | None = None;
        for t in incompat.terms.values() {
            acc = self._accumulated(t.package);
            if acc is not None and acc.satisfies(t) {
                continue;
            }
            if acc is not None and acc.is_disjoint(t) {
                return ("contradicted", None);
            }
            if unresolved is not None {
                return ("inconclusive", None);
            }
            unresolved = t;
        }
        if unresolved is None {
            return ("satisfied", None);
        }
        return ("almost", unresolved);
    }

    def _propagate(package: str) {
        changed: list[str] = [package];
        while changed {
            name = changed.pop();
            for incompat in reversed(list(self.incompatibilities.get(name, []))) {
                (rel, term) = self._relation(incompat);
                if rel == "satisfied" {
                    root_cause = self._resolve_conflict(incompat);
                    (rel2, term2) = self._relation(root_cause);
                    if rel2 != "almost" or term2 is None {
                        raise SolveFailure(
                            incompatibility=root_cause, root_name=self.root_name
                        );
                    }
                    self._derive(term2.negate(), root_cause);
                    changed = [term2.package];
                    break;
                }
                if rel == "almost" and term is not None {
                    self._derive(term.negate(), incompat);
                    if term.package not in changed {
                        changed.append(term.package);
                    }
                }
            }
        }
    }

    def _derive(term: Term, cause: Incompatibility) {
        self.assignments.append(Assignment(term=term, level=self.level, cause=cause));
    }

    def _satisfier(incompat: Incompatibility) -> tuple[int, int] {
        acc: dict[str, Term] = {};
        for (idx, a) in enumerate(self.assignments) {
            name = a.term.package;
            acc[name] = a.term if name not in acc else acc[name].intersect(a.term);
            if all(
                (t.package in acc and acc[t.package].satisfies(t))
                for t in incompat.terms.values()
            ) {
                return (idx, self._previous_level(incompat, idx));
            }
        }
        raise RuntimeError("version solver: conflict with no satisfier");
    }

    def _previous_level(incompat: Incompatibility, sat_idx: int) -> int {
        satisfier = self.assignments[sat_idx];
        acc: dict[str, Term] = {satisfier.term.package: satisfier.term};
        if all(
            (t.package in acc and acc[t.package].satisfies(t))
            for t in incompat.terms.values()
        ) {
            return 1;
        }
        for a in self.assignments[:sat_idx] {
            name = a.term.package;
            acc[name] = a.term if name not in acc else acc[name].intersect(a.term);
            if all(
                (t.package in acc and acc[t.package].satisfies(t))
                for t in incompat.terms.values()
            ) {
                return max(a.level, 1);
            }
        }
        return 1;
    }

    def _resolve_conflict(incompat: Incompatibility) -> Incompatibility {
        original = incompat;
        while not incompat.is_failure(self.root_name) {
            (sat_idx, previous_level) = self._satisfier(incompat);
            satisfier = self.assignments[sat_idx];
            if satisfier.is_decision() or previous_level != satisfier.level {
                if incompat is not original {
                    self._add(incompat);
                }
                self._backtrack(previous_level);
                return incompat;
            }
            cause = satisfier.cause;
            if cause is None {
                raise RuntimeError(
                    "version solver: derived assignment without a cause"
                );
            }
            name = satisfier.term.package;
            terms = [
                t
                for t in list(incompat.terms.values()) + list(cause.terms.values())
                if t.package != name
            ];
            term = incompat.terms[name];
            if not satisfier.term.satisfies(term) {
                terms.append(satisfier.term.difference(term).negate());
            }
            incompat = Incompatibility.of(
                terms, CauseKind.DERIVED, left=incompat, right=cause
            );
        }
        raise SolveFailure(incompatibility=incompat, root_name=self.root_name);
    }

    def _backtrack(level: int) {
        self.assignments = [
            a
            for a in self.assignments
            if a.level <= level
        ];
        self.level = level;
        self.decisions = {
            a.term.package: self.decisions[a.term.package]
            for a in self.assignments
            if a.is_decision() and a.term.package in self.decisions
        };
    }

    def _candidates_for(name: str) -> list[Version] {
        if name not in self._candidates {
            self._candidates[name] = sorted(self.source.versions(name), reverse=True);
        }
        return self._candidates[name];
    }

    def _allowed(name: str, term: Term) -> list[Version] {
        pre = self.source.allows_prerelease(name);
        return [
            v
            for v in self._candidates_for(name)
            if term.versions.contains(v) and (pre or not v.is_prerelease())
        ];
    }

    def _decide -> str | None {
        pending: list[tuple[int, str, Term]] = [];
        seen: set[str] = set();
        for a in self.assignments {
            name = a.term.package;
            if name in seen or name in self.decisions {
                continue;
            }
            seen.add(name);
            acc = self._accumulated(name);
            if acc is not None and acc.positive {
                pending.append((len(self._allowed(name, acc)), name, acc));
            }
        }
        if not pending {
            return None;
        }
        pending.sort(key=lambda (item: tuple[int, str, Term]) { (item[0], item[1]); });
        (_, name, term) = pending[0];
        if name == self.root_name {
            self._decide_version(name, self.root_version);
            return name;
        }
        allowed = self._allowed(name, term);
        if not allowed {
            self._add(Incompatibility.of([term], CauseKind.NO_VERSIONS));
            return name;
        }
        preferred = self.source.preferred(name);
        version = preferred
            if (preferred is not None and preferred in allowed)
            else allowed[0];
        reason = self.source.unavailable_reason(name, version);
        if reason {
            self._add(
                Incompatibility.of(
                    [Term(package=name, versions=VersionSet.exact(version))],
                    CauseKind.UNAVAILABLE,
                    note=reason
                )
            );
            return name;
        }
        self._decide_version(name, version);
        return name;
    }

    def _decide_version(name: str, version: Version) {
        conflict = False;
        for (dep, req) in self.source.dependencies(name, version).items() {
            incompat = Incompatibility.of(
                [
                    Term(package=name, versions=VersionSet.exact(version)),
                    Term(package=dep, versions=req.versions, positive=False)
                ],
                CauseKind.DEPENDENCY
            );
            self._add(incompat);
            if self._would_satisfy(incompat, name, version) {
                conflict = True;
            }
        }
        if not conflict {
            self.level += 1;
            self.assignments.append(
                Assignment(
                    term=Term(package=name, versions=VersionSet.exact(version)),
                    level=self.level
                )
            );
            self.decisions[name] = version;
        }
    }

    def _would_satisfy(incompat: Incompatibility, name: str, version: Version) -> bool {
        decided = Term(package=name, versions=VersionSet.exact(version));
        for t in incompat.terms.values() {
            acc = self._accumulated(t.package);
            if t.package == name {
                acc = decided if acc is None else acc.intersect(decided);
            }
            if acc is None or not acc.satisfies(t) {
                return False;
            }
        }
        return True;
    }
}

def explain(incompat: Incompatibility, root_name: str) -> str {
    lines: list[str] = [];
    numbered: dict[int, int] = {};

    def walk_cause(cause_node: Incompatibility) -> str {
        if cause_node.kind != CauseKind.DERIVED
            or cause_node.left is None
            or cause_node.right is None {
            return cause_node.describe(root_name);
        }
        key = id(cause_node);
        if key in numbered {
            return f"{cause_node.describe(root_name)} ({numbered[key]})";
        }
        left = walk_cause(cause_node.left);
        right = walk_cause(cause_node.right);
        lines.append(f"Because {left} and {right}, {cause_node.describe(root_name)}.");
        numbered[key] = len(lines);
        return cause_node.describe(root_name);
    }
    top = walk_cause(incompat);
    if not lines {
        return f"Version solving failed: {top}.";
    }
    lines[-1] = lines[-1].rstrip(".") + ", so version solving failed.";
    if len(lines) == 1 {
        return lines[0];
    }
    return "\n".join([f"{i + 1}. {line}" for (i, line) in enumerate(lines)]);
}

def solve(
    source: PackageSource,
    root_name: str,
    root_version: Version,
    root_deps: dict[str, Requirement]
) -> dict[str, Version] {
    wrapped = _RootedSource(
        inner=source,
        root_name=root_name,
        root_version=root_version,
        root_deps=root_deps
    );
    return Solver(
        source=wrapped, root_name=root_name, root_version=root_version
    ).solve();
}

obj _RootedSource(PackageSource) {
    has inner: PackageSource,
        root_name: str,
        root_version: Version,
        root_deps: dict[str, Requirement];

    override def versions(name: str) -> list[Version] {
        if name == self.root_name {
            return [self.root_version];
        }
        return self.inner.versions(name);
    }

    override def dependencies(name: str, version: Version) -> dict[str, Requirement] {
        if name == self.root_name {
            return self.root_deps;
        }
        return self.inner.dependencies(name, version);
    }

    override def unavailable_reason(name: str, version: Version) -> str {
        return ""
            if name == self.root_name
            else self.inner.unavailable_reason(name, version);
    }

    override def preferred(name: str) -> Version | None {
        return None if name == self.root_name else self.inner.preferred(name);
    }

    override def allows_prerelease(name: str) -> bool {
        return self.inner.allows_prerelease(name);
    }
}
