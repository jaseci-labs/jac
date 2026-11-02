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

    override def allows_prerelease(name: str) -> bool {
        return False;
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
