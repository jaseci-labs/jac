"""Registry hygiene: every component npm dependency must carry a bounded
version range. Unpinned deps resolve to whatever major is current at
install time and break vendored components when upstream APIs move (the
resizable component targets react-resizable-panels v2; v4 renamed its
exports and broke fresh scaffolds)."""

import os;
import re;
import json;
import from tests.support { JAC_ROOT }

glob REGISTRY = os.path.join(
         JAC_ROOT, "jaclang", "cli", "shadcn", "registry", "registry.json"
     ),
     COMPONENTS = os.path.join(
         JAC_ROOT, "jaclang", "cli", "shadcn", "registry", "components", "ui"
     );

"""Lines where a spread of the component's full props follows its merged
className inside one JSX opening tag. A later attribute wins, so that spread
replaces `cn(base, props["className"])` with the caller's bare className and
the component loses its own classes whenever a className is passed."""
def spreads_after_class(src: str) -> list[int] {
    full = {"props"}
        | set(re.findall(r"(\w+)\s*(?::[^=\n]+)?=\s*\{\*\*\s*props\s*\};", src));
    bad: list[int] = [];
    for m in re.finditer(r"className=\{", src) {
        depth = 0;
        i = m.end() - 1;
        while i < len(src) {
            ch = src[i];
            if ch == "{" {
                spread = re.`match(r"\{\*\*\s*(\w+)\}", src[i:])
                    if depth == 0
                    else None;
                if spread is not None and spread.group(1) in full {
                    bad.append(src.count("\n", 0, i) + 1);
                }
                depth += 1;
            } elif ch == "}" {
                depth -= 1;
            } elif ch == ">" and depth == 0 {
                break;
            }
            i += 1;
        }
    }
    return bad;
}

def load_registry -> dict[str, any] {
    with open(REGISTRY) as f {
        return json.load(f);
    }
}

test "every component npm dep has a pinned version range" {
    reg = load_registry();
    dep_versions: dict[str, any] = reg.get("depVersions", {});
    missing: list[str] = [];
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

test "a merged className is never overridden by the props spread" {
    offenders: list[str] = [];
    for name in sorted(os.listdir(COMPONENTS)) {
        if name.endswith(".jac") {
            with open(os.path.join(COMPONENTS, name)) as f {
                for line in spreads_after_class(f.read()) {
                    offenders.append(f"{name}:{line}");
                }
            }
        }
    }
    assert not offenders , f"props spread after a merged className (move className after the spread): {offenders}";
}
