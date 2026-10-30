import from jaclang.packages.pubgrub { PackageSource, SolveFailure, solve }
import from jaclang.packages.semver { Requirement, Version }

obj MemorySource(PackageSource) {
    has registry: dict[str, dict[str, dict[str, str]]] = {},
        locked: dict[str, str] = {},
        broken: dict[str, str] = {};

    override def versions(name: str) -> list[Version] {
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
        pinned = self.locked.get(name);
        return Version.parse(pinned) if pinned else None;
    }
}

obj CountingSource(MemorySource) {
    has fetched: list[str] = [];

    override def versions(name: str) -> list[Version] {
        self.fetched.append(name);
        return super.versions(name);
    }
}

def _solve(
    registry: dict[str, dict[str, dict[str, str]]],
    deps: dict[str, str],
    locked: dict[str, str] | None = None,
    broken: dict[str, str] | None = None
) -> dict[str, str] {
    picked = solve(
        MemorySource(registry=registry, locked=locked or {}, broken=broken or {}),
        "app/root",
        Version.parse("0.1.0"),
        {name: Requirement.parse(req) for (name, req) in deps.items()}
    );
    return {name: str(v) for (name, v) in picked.items()};
}

test "the newest compatible version of every package is chosen" {
    registry = {
        "a/one": {"1.0.0": {"a/two": "^1"}, "1.1.0": {"a/two": "^1.2"}},
        "a/two": {"1.0.0": {}, "1.2.0": {}, "1.3.0": {}, "2.0.0": {}}
    };
    assert _solve(registry, {"a/one": "^1"}) == {"a/one": "1.1.0", "a/two": "1.3.0"};
}

test "the solver backtracks out of a conflicting newest version" {
    registry = {
        "a/web": {"1.0.0": {"a/core": "^1"}, "2.0.0": {"a/core": "^2"}},
        "a/tool": {"1.0.0": {"a/core": "^1"}},
        "a/core": {"1.0.0": {}, "1.4.0": {}, "2.0.0": {}}
    };
    assert _solve(registry, {"a/web": "*", "a/tool": "^1"})
        == {"a/web": "1.0.0", "a/tool": "1.0.0", "a/core": "1.4.0"};
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

test "an unsatisfiable registry explains the conflict" {
    registry = {
        "a/web": {"1.0.0": {"a/core": "^2"}},
        "a/tool": {"1.0.0": {"a/core": "^1"}},
        "a/core": {"1.0.0": {}, "2.0.0": {}}
    };
    try {
        _solve(registry, {"a/web": "^1", "a/tool": "^1"});
        assert False , "expected a solve failure";
    } except SolveFailure as e {
        message = str(e);
        assert "a/core" in message , message;
        assert "version solving failed" in message , message;
    }
}

test "a missing package is reported, not crashed on" {
    try {
        _solve({}, {"a/ghost": "^1"});
        assert False , "expected a solve failure";
    } except SolveFailure as e {
        assert "a/ghost" in str(e);
    }
}

test "a rejected candidate does not enable prereleases" {
    registry = {
        "a/bridge": {
            "1.0.0": {},
            "2.0.0": {"a/lib": ">=1.5.0-beta.1", "a/missing": "^1"}
        },
        "a/lib": {"1.0.0": {}, "1.1.0": {}, "1.2.0": {}, "1.5.0-beta.1": {}}
    };
    expected = {"a/bridge": "1.0.0", "a/lib": "1.2.0"};
    assert _solve(registry, {"a/bridge": "*", "a/lib": "^1"}) == expected;
    del registry["a/bridge"]["2.0.0"];
    assert _solve(registry, {"a/bridge": "*", "a/lib": "^1"}) == expected;
}

test "a root prerelease requirement survives backtracking" {
    registry = {
        "a/bridge": {"1.0.0": {}, "2.0.0": {"a/missing": "^1"}},
        "a/lib": {"1.0.0": {}, "1.5.0-beta.1": {}}
    };
    assert _solve(registry, {"a/bridge": "*", "a/lib": ">=1.5.0-beta.1"})
        == {"a/bridge": "1.0.0", "a/lib": "1.5.0-beta.1"};
}

test "a surviving transitive prerelease requirement survives backtracking" {
    registry = {
        "a/tool": {"1.0.0": {"a/lib": ">=1.5.0-beta.1"}},
        "a/web": {"1.0.0": {}, "2.0.0": {"a/missing": "^1"}},
        "a/lib": {"1.0.0": {}, "1.5.0-beta.1": {}, "1.6.0-beta.1": {}}
    };
    assert _solve(registry, {"a/tool": "^1", "a/web": "*"})
        == {"a/tool": "1.0.0", "a/web": "1.0.0", "a/lib": "1.6.0-beta.1"};
}

test "a transitive prerelease requirement can replace a stable decision" {
    registry = {
        "a/tool": {"1.0.0": {"a/lib": ">=1.5.0-beta.1"}},
        "a/lib": {"1.0.0": {}, "1.5.0-beta.1": {}}
    };
    assert _solve(registry, {"a/tool": "^1", "a/lib": "^1"})
        == {"a/tool": "1.0.0", "a/lib": "1.5.0-beta.1"};
}

test "a redundant prerelease opt-in survives later range narrowing" {
    registry = {
        "a/tool": {"1.0.0": {"a/lib": ">=1.0.0-beta.1", "a/zconstraint": "^1"}},
        "a/zconstraint": {"1.0.0": {"a/lib": ">=1.4.0"}},
        "a/lib": {"1.0.0": {}, "1.2.0": {}, "1.5.0-beta.1": {}}
    };
    assert _solve(registry, {"a/tool": "^1", "a/lib": "^1"})
        == {"a/tool": "1.0.0", "a/zconstraint": "1.0.0", "a/lib": "1.5.0-beta.1"};
    registry["a/tool"]["1.1.0"] = registry["a/tool"]["1.0.0"];
    assert _solve(registry, {"a/tool": "^1", "a/lib": "^1"})
        == {"a/tool": "1.1.0", "a/zconstraint": "1.0.0", "a/lib": "1.5.0-beta.1"};
}

test "a missing prerelease opt-in can backtrack to an older provider" {
    registry = {
        "a/tool": {
            "1.0.0": {"a/lib": ">=1.0.0-beta.1"},
            "2.0.0": {},
            "3.0.0": {"a/lib": ">=1.0.0-beta.1", "a/missing": "^1"}
        },
        "a/lib": {"1.2.0": {}, "1.5.0-beta.1": {}}
    };
    assert _solve(registry, {"a/tool": "*", "a/lib": ">=1.4.0"})
        == {"a/tool": "1.0.0", "a/lib": "1.5.0-beta.1"};
}

test "a prerelease opt-in can come from a package an older version brings in" {
    registry = {
        "a/web": {"1.0.0": {"a/tool": "^1"}, "2.0.0": {}},
        "a/tool": {"1.0.0": {"a/lib": ">=1.0.0-beta.1"}},
        "a/lib": {"1.2.0": {}, "1.5.0-beta.1": {}}
    };
    assert _solve(registry, {"a/web": "*", "a/lib": ">=1.4.0"})
        == {"a/web": "1.0.0", "a/tool": "1.0.0", "a/lib": "1.5.0-beta.1"};
}

test "a prerelease no package can opt into fails without trying every version" {
    registry: dict[str, dict[str, dict[str, str]]] = {
        "a/lib": {"1.2.0": {}, "1.5.0-beta.1": {}}
    };
    deps = {"a/lib": ">=1.4.0"};
    for i in range(30) {
        registry[f"a/u{i}"] = {"1.0.0": {}, "2.0.0": {}};
        deps[f"a/u{i}"] = "*";
    }
    try {
        _solve(registry, deps);
        assert False , "expected a solve failure";
    } except SolveFailure as e {
        message = str(e);
        assert "a/lib >=1.4.0" in message , message;
        assert "only prereleases match" in message , message;
        assert len(message.splitlines()) == 1 , message;
    }
}

test "a prerelease opt-in can pass along a chain of prereleases" {
    registry = {
        "a/tool": {"1.0.0": {"a/mid": ">=1.4.0-beta.1"}, "2.0.0": {}},
        "a/mid": {"1.5.0-beta.1": {"a/lib": ">=1.4.0-beta.1"}},
        "a/lib": {"1.5.0-beta.1": {}}
    };
    assert _solve(registry, {"a/lib": ">=1.4.0", "a/mid": ">=1.4.0", "a/tool": "*"})
        == {"a/tool": "1.0.0", "a/mid": "1.5.0-beta.1", "a/lib": "1.5.0-beta.1"};
}

test "a shared dependency's version can decide a prerelease opt-in" {
    with_x = {"a/n": "^1", "a/x": "*"};
    registry = {
        "a/n": {"1.0.0": {}, "2.0.0": {}},
        "a/y": {"1.0.0": with_x, "1.1.0": with_x, "1.2.0": with_x, "1.5.0-beta.1": {}},
        "a/x": {"1.0.0": {"a/lib": ">=1.0.0-beta.1"}},
        "a/lib": {"1.5.0-beta.1": {}}
    };
    assert _solve(registry, {"a/n": "*", "a/y": "*", "a/lib": ">=1.4.0"})
        == {"a/n": "1.0.0", "a/y": "1.2.0", "a/x": "1.0.0", "a/lib": "1.5.0-beta.1"};
}

test "packages unrelated to a prerelease opt-in are not retried" {
    registry: dict[str, dict[str, dict[str, str]]] = {
        "a/lib": {"1.2.0": {}, "1.5.0-beta.1": {}},
        "a/tool": {"1.0.0": {}, "2.0.0": {"a/lib": ">=1.0.0-beta.1", "a/missing": "^1"}}
    };
    deps = {"a/lib": ">=1.4.0", "a/tool": "*"};
    for i in range(30) {
        registry[f"a/u{i}"] = {"1.0.0": {}, "2.0.0": {f"a/w{i}": "*"}};
        registry[f"a/w{i}"] = {"1.0.0": {}};
        deps[f"a/u{i}"] = "*";
    }
    try {
        _solve(registry, deps);
        assert False , "expected a solve failure";
    } except SolveFailure as e {
        message = str(e);
        assert "only prereleases match" in message , message;
        assert len(message.splitlines()) < 10 , message;
    }
}

test "a shared parent does not make unrelated siblings retried" {
    bundle_deps = {"a/tool": "*"};
    registry: dict[str, dict[str, dict[str, str]]] = {
        "a/lib": {"1.2.0": {}, "1.5.0-beta.1": {}},
        "a/tool": {"1.0.0": {}, "2.0.0": {"a/lib": ">=1.0.0-beta.1", "a/missing": "^1"}}
    };
    for i in range(30) {
        registry[f"a/u{i}"] = {"1.0.0": {}, "2.0.0": {}};
        bundle_deps[f"a/u{i}"] = "*";
    }
    registry["a/bundle"] = {"1.0.0": bundle_deps};
    try {
        _solve(registry, {"a/lib": ">=1.4.0", "a/bundle": "*"});
        assert False , "expected a solve failure";
    } except SolveFailure as e {
        message = str(e);
        assert "only prereleases match" in message , message;
        assert len(message.splitlines()) < 10 , message;
    }
}

test "a prerelease gap reads no index only an unselectable version needs" {
    source = CountingSource(
        registry={
            "a/lib": {"1.2.0": {}, "1.5.0-beta.1": {}},
            "a/old": {"1.0.0": {"a/ancient": "^1"}, "2.0.0": {}},
            "a/ancient": {"1.0.0": {"a/lib": ">=1.0.0-beta.1"}}
        }
    );
    try {
        solve(
            source,
            "app/root",
            Version.parse("0.1.0"),
            {"a/lib": Requirement.parse(">=1.4.0"), "a/old": Requirement.parse("^2")}
        );
        assert False , "expected a solve failure";
    } except SolveFailure as e {
        assert "only prereleases match" in str(e) , str(e);
    }
    assert "a/ancient" not in source.fetched , source.fetched;
}
