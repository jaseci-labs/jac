import from jaclang.packages.pubgrub { PackageSource, SolveFailure, solve }
import from jaclang.packages.semver { Requirement, Version }

glob DECISION_BUDGET: int = 100;

obj MemorySource(PackageSource) {
    has registry: dict[str, dict[str, dict[str, str]]] = {},
        locked: dict[str, str] = {},
        broken: dict[str, str] = {},
        fetched: list[str] = [],
        decided: int = 0;

    override def versions(name: str) -> list[Version] {
        self.fetched.append(name);
        return [Version.parse(v) for v in self.registry.get(name, {})];
    }

    override def dependencies(name: str, version: Version) -> dict[str, Requirement] {
        deps = self.registry.get(name, {}).get(str(version), {});
        return {dep: Requirement.parse(req) for (dep, req) in deps.items()};
    }

    override def unavailable_reason(name: str, version: Version) -> str {
        return self.broken.get(f"{name}@{version}", "");
    }

    override def preferred(name: str) -> Version | None {
        self.decided += 1;
        assert self.decided <= DECISION_BUDGET , f"over {DECISION_BUDGET} decisions";
        pinned = self.locked.get(name);
        return Version.parse(pinned) if pinned else None;
    }
}

def _solve_in(source: MemorySource, deps: dict[str, str]) -> dict[str, str] {
    picked = solve(
        source,
        "app/root",
        Version.parse("0.1.0"),
        {name: Requirement.parse(req) for (name, req) in deps.items()}
    );
    return {name: str(v) for (name, v) in picked.items()};
}

def _solve(
    registry: dict[str, dict[str, dict[str, str]]],
    deps: dict[str, str],
    locked: dict[str, str] | None = None,
    broken: dict[str, str] | None = None
) -> dict[str, str] {
    return _solve_in(
        MemorySource(registry=registry, locked=locked or {}, broken=broken or {}), deps
    );
}

def _siblings(
    registry: dict[str, dict[str, dict[str, str]]],
    deps: dict[str, str],
    linked: bool = False
) -> dict[str, dict[str, dict[str, str]]] {
    for i in range(30) {
        registry[f"a/u{i}"] = {
            "1.0.0": {},
            "2.0.0": {f"a/w{i}": "*"} if linked else {}
        };
        if linked {
            registry[f"a/w{i}"] = {"1.0.0": {}};
        }
        deps[f"a/u{i}"] = "*";
    }
    return registry;
}

test "the solver selects these versions" {
    with_x = {"a/n": "^1", "a/x": "*"};
    lib = {"1.0.0": {}, "1.1.0": {}, "1.2.0": {}, "1.5.0-beta.1": {}};
    narrowing = {"a/lib": ">=1.0.0-beta.1", "a/zconstraint": "^1"};
    rows = [
        (
            "the newest compatible version of every package",
            {
                "a/one": {"1.0.0": {"a/two": "^1"}, "1.1.0": {"a/two": "^1.2"}},
                "a/two": {"1.0.0": {}, "1.2.0": {}, "1.3.0": {}, "2.0.0": {}}
            },
            {"a/one": "^1"},
            {"a/one": "1.1.0", "a/two": "1.3.0"}
        ),
        (
            "backtracking out of a conflicting newest version",
            {
                "a/web": {"1.0.0": {"a/core": "^1"}, "2.0.0": {"a/core": "^2"}},
                "a/tool": {"1.0.0": {"a/core": "^1"}},
                "a/core": {"1.0.0": {}, "1.4.0": {}, "2.0.0": {}}
            },
            {"a/web": "*", "a/tool": "^1"},
            {"a/web": "1.0.0", "a/tool": "1.0.0", "a/core": "1.4.0"}
        ),
        (
            "a rejected candidate does not enable prereleases",
            {
                "a/bridge": {
                    "1.0.0": {},
                    "2.0.0": {"a/lib": ">=1.5.0-beta.1", "a/missing": "^1"}
                },
                "a/lib": lib
            },
            {"a/bridge": "*", "a/lib": "^1"},
            {"a/bridge": "1.0.0", "a/lib": "1.2.0"}
        ),
        (
            "the same project without the rejected candidate",
            {"a/bridge": {"1.0.0": {}}, "a/lib": lib},
            {"a/bridge": "*", "a/lib": "^1"},
            {"a/bridge": "1.0.0", "a/lib": "1.2.0"}
        ),
        (
            "a root prerelease requirement survives backtracking",
            {
                "a/bridge": {"1.0.0": {}, "2.0.0": {"a/missing": "^1"}},
                "a/lib": {"1.0.0": {}, "1.5.0-beta.1": {}}
            },
            {"a/bridge": "*", "a/lib": ">=1.5.0-beta.1"},
            {"a/bridge": "1.0.0", "a/lib": "1.5.0-beta.1"}
        ),
        (
            "a surviving transitive prerelease requirement survives backtracking",
            {
                "a/tool": {"1.0.0": {"a/lib": ">=1.5.0-beta.1"}},
                "a/web": {"1.0.0": {}, "2.0.0": {"a/missing": "^1"}},
                "a/lib": {"1.0.0": {}, "1.5.0-beta.1": {}, "1.6.0-beta.1": {}}
            },
            {"a/tool": "^1", "a/web": "*"},
            {"a/tool": "1.0.0", "a/web": "1.0.0", "a/lib": "1.6.0-beta.1"}
        ),
        (
            "a transitive prerelease requirement can replace a stable decision",
            {
                "a/tool": {"1.0.0": {"a/lib": ">=1.5.0-beta.1"}},
                "a/lib": {"1.0.0": {}, "1.5.0-beta.1": {}}
            },
            {"a/tool": "^1", "a/lib": "^1"},
            {"a/tool": "1.0.0", "a/lib": "1.5.0-beta.1"}
        ),
        (
            "a redundant prerelease opt-in survives later range narrowing",
            {
                "a/tool": {"1.0.0": narrowing},
                "a/zconstraint": {"1.0.0": {"a/lib": ">=1.4.0"}},
                "a/lib": {"1.0.0": {}, "1.2.0": {}, "1.5.0-beta.1": {}}
            },
            {"a/tool": "^1", "a/lib": "^1"},
            {"a/tool": "1.0.0", "a/zconstraint": "1.0.0", "a/lib": "1.5.0-beta.1"}
        ),
        (
            "the same opt-in from the newer of two identical versions",
            {
                "a/tool": {"1.0.0": narrowing, "1.1.0": narrowing},
                "a/zconstraint": {"1.0.0": {"a/lib": ">=1.4.0"}},
                "a/lib": {"1.0.0": {}, "1.2.0": {}, "1.5.0-beta.1": {}}
            },
            {"a/tool": "^1", "a/lib": "^1"},
            {"a/tool": "1.1.0", "a/zconstraint": "1.0.0", "a/lib": "1.5.0-beta.1"}
        ),
        (
            "a missing prerelease opt-in can backtrack to an older provider",
            {
                "a/tool": {
                    "1.0.0": {"a/lib": ">=1.0.0-beta.1"},
                    "2.0.0": {},
                    "3.0.0": {"a/lib": ">=1.0.0-beta.1", "a/missing": "^1"}
                },
                "a/lib": {"1.2.0": {}, "1.5.0-beta.1": {}}
            },
            {"a/tool": "*", "a/lib": ">=1.4.0"},
            {"a/tool": "1.0.0", "a/lib": "1.5.0-beta.1"}
        ),
        (
            "a prerelease opt-in from a package an older version brings in",
            {
                "a/web": {"1.0.0": {"a/tool": "^1"}, "2.0.0": {}},
                "a/tool": {"1.0.0": {"a/lib": ">=1.0.0-beta.1"}},
                "a/lib": {"1.2.0": {}, "1.5.0-beta.1": {}}
            },
            {"a/web": "*", "a/lib": ">=1.4.0"},
            {"a/web": "1.0.0", "a/tool": "1.0.0", "a/lib": "1.5.0-beta.1"}
        ),
        (
            "a prerelease opt-in passed along a chain of prereleases",
            {
                "a/tool": {"1.0.0": {"a/mid": ">=1.4.0-beta.1"}, "2.0.0": {}},
                "a/mid": {"1.5.0-beta.1": {"a/lib": ">=1.4.0-beta.1"}},
                "a/lib": {"1.5.0-beta.1": {}}
            },
            {"a/lib": ">=1.4.0", "a/mid": ">=1.4.0", "a/tool": "*"},
            {"a/tool": "1.0.0", "a/mid": "1.5.0-beta.1", "a/lib": "1.5.0-beta.1"}
        ),
        (
            "a shared dependency's version decides a prerelease opt-in",
            {
                "a/n": {"1.0.0": {}, "2.0.0": {}},
                "a/y": {
                    "1.0.0": with_x,
                    "1.1.0": with_x,
                    "1.2.0": with_x,
                    "1.5.0-beta.1": {}
                },
                "a/x": {"1.0.0": {"a/lib": ">=1.0.0-beta.1"}},
                "a/lib": {"1.5.0-beta.1": {}}
            },
            {"a/n": "*", "a/y": "*", "a/lib": ">=1.4.0"},
            {"a/n": "1.0.0", "a/y": "1.2.0", "a/x": "1.0.0", "a/lib": "1.5.0-beta.1"}
        )
    ];
    failed: list[str] = [];
    for (label, registry, deps, expected) in rows {
        try {
            if _solve(registry, deps) != expected {
                failed.append(label);
            }
        } except Exception as e {
            failed.append(f"{label}: {e}");
        }
    }
    assert not failed , failed;
}

test "a locked version is kept while it still satisfies the registry" {
    registry = {"a/lib": {"1.0.0": {}, "1.1.0": {}, "1.2.0": {}}};
    assert _solve(registry, {"a/lib": "^1"}, locked={"a/lib": "1.1.0"})
        == {"a/lib": "1.1.0"};
    assert _solve(registry, {"a/lib": "^1.2"}, locked={"a/lib": "1.1.0"})
        == {"a/lib": "1.2.0"};
}

test "an unavailable version is skipped for an older one" {
    registry = {"a/lib": {"1.0.0": {}, "1.1.0": {}}};
    assert _solve(registry, {"a/lib": "^1"}, broken={"a/lib@1.1.0": "needs jac >=9"})
        == {"a/lib": "1.0.0"};
}

test "an unsolvable registry fails fast and explains itself" {
    lib = {"1.2.0": {}, "1.5.0-beta.1": {}};
    granter = {"1.0.0": {}, "2.0.0": {"a/lib": ">=1.0.0-beta.1", "a/missing": "^1"}};
    lonely = {"a/lib": ">=1.4.0"};
    unrelated = {"a/lib": ">=1.4.0", "a/tool": "*"};
    bundled = {"a/tool": "*"};
    circular = {"a/lib": ">=1.4.0"};
    circular_registry = _siblings(
        {
            "a/lib": {"1.2.0": {}, "1.5.0-beta.1": {"a/g": "*"}},
            "a/g": {"1.0.0": {"a/lib": ">=1.0.0-beta.1"}}
        },
        circular
    );
    for i in range(30) {
        circular_registry[f"a/u{i}"]["1.0.0"] = {"a/lib": "*"};
    }
    rows = [
        (
            "two requirements on one package conflict",
            {
                "a/web": {"1.0.0": {"a/core": "^2"}},
                "a/tool": {"1.0.0": {"a/core": "^1"}},
                "a/core": {"1.0.0": {}, "2.0.0": {}}
            },
            {"a/web": "^1", "a/tool": "^1"},
            ["a/core", "version solving failed"],
            20,
            []
        ),
        ("a missing package", {}, {"a/ghost": "^1"}, ["a/ghost"], 1, []),
        (
            "a prerelease no package can opt into",
            _siblings({"a/lib": lib}, lonely),
            lonely,
            ["a/lib >=1.4.0", "only prereleases match"],
            1,
            []
        ),
        (
            "packages unrelated to a prerelease opt-in",
            _siblings({"a/lib": lib, "a/tool": granter}, unrelated, linked=True),
            unrelated,
            ["only prereleases match"],
            9,
            []
        ),
        (
            "a shared parent of a prerelease opt-in and unrelated siblings",
            _siblings({"a/lib": lib, "a/tool": granter}, bundled)
                | {"a/bundle": {"1.0.0": bundled}},
            {"a/lib": ">=1.4.0", "a/bundle": "*"},
            ["only prereleases match"],
            9,
            []
        ),
        (
            "a prerelease whose only opt-in comes from its own dependency",
            circular_registry,
            circular,
            ["only prereleases match"],
            9,
            []
        ),
        (
            "an opt-in only an unselectable version could bring in",
            {
                "a/lib": lib,
                "a/old": {"1.0.0": {"a/ancient": "^1"}, "2.0.0": {}},
                "a/ancient": {"1.0.0": {"a/lib": ">=1.0.0-beta.1"}}
            },
            {"a/lib": ">=1.4.0", "a/old": "^2"},
            ["only prereleases match"],
            9,
            ["a/ancient"]
        )
    ];
    failed: list[str] = [];
    for (label, registry, deps, needles, max_lines, unread) in rows {
        source = MemorySource(registry=registry);
        problem = "";
        try {
            _solve_in(source, deps);
            problem = "solved";
        } except SolveFailure as e {
            message = str(e);
            if not all(needle in message for needle in needles) {
                problem = message;
            } elif len(message.splitlines()) > max_lines {
                problem = f"{len(message.splitlines())} lines";
            }
        } except AssertionError as e {
            problem = str(e);
        }
        if not problem and any(name in source.fetched for name in unread) {
            problem = f"read {source.fetched}";
        }
        if problem {
            failed.append(f"{label}: {problem}");
        }
    }
    assert not failed , failed;
}
