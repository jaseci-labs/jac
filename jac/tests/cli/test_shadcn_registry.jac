"""Registry hygiene: every component npm dependency must carry a bounded
version range. Unpinned deps resolve to whatever major is current at
install time and break vendored components when upstream APIs move (the
resizable component targets react-resizable-panels v2; v4 renamed its
exports and broke fresh scaffolds)."""

import os;
import json;
import from tests.support { JAC_ROOT }

glob REGISTRY = os.path.join(
         JAC_ROOT, "jaclang", "cli", "shadcn", "registry", "registry.json"
     );

def load_registry -> dict {
    with open(REGISTRY) as f {
        return json.load(f);
    }
}

test "every component npm dep has a pinned version range" {
    reg = load_registry();
    dep_versions: dict = reg.get("depVersions", {});
    missing: list = [];
    for (name, comp) in reg["components"].items() {
        for dep in comp.get("npmDeps", []) {
            rng = dep_versions.get(dep, "*");
            if rng == "*" or rng == "" {
                missing.append(name + " -> " + dep);
            }
        }
    }
    assert not missing , f"unpinned registry deps (add to registry depVersions): {missing}";
}

test "shared and pinned ranges are bounded" {
    reg = load_registry();
    for (dep, rng) in reg.get("sharedDeps", {}).items() {
        assert rng != "*" , f"sharedDeps unbounded: {dep}";
    }
    for (dep, rng) in reg.get("depVersions", {}).items() {
        assert str(rng).startswith(("^", "~", ">=")) or str(rng)[0].isdigit() , f"depVersions range malformed: {dep} = {rng}";
    }
}

test "component lookup accepts underscore spellings" {
    import from jaclang.cli.shadcn.shadcn_handler { _resolve_peer_deps }
    reg = load_registry();
    resolved = _resolve_peer_deps(["scroll_area"], reg, set());
    assert "scroll-area" in resolved , f"underscored name should resolve to the hyphenated registry key, got {resolved}";
}
