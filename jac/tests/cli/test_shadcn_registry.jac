"""Registry hygiene: every component npm dependency must carry a bounded
version range. Unpinned deps resolve to whatever major is current at
install time and break vendored components when upstream APIs move (the
resizable component targets react-resizable-panels v2; v4 renamed its
exports and broke fresh scaffolds)."""

import os;
import re;
import json;
import subprocess;
import from tempfile { TemporaryDirectory }
import from tests.support { JAC_ROOT }
import from jaclang.client.bun_installer { get_bun }
import from jaclang.compiler.driver.program { JacProgram }

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

"""Compile one registry component and run `checks` against it under Bun with
React, the JSX factory and the sibling components replaced by recording
stubs, so a component's own prop handling runs for real."""
def run_component(name: str, checks: str) {
    bun = get_bun();
    if bun is None {
        testskip("Bun is required to execute generated JavaScript");
    }
    prog = JacProgram();
    mod = prog.compile(os.path.join(COMPONENTS, name));
    assert not prog.errors_had , str(prog.errors_had);
    js = re.sub(r"import[^;]+;", "", mod.gen.js);
    stubs = """
const __jacJsx = (tag, props, children) => ({tag, props: props || {}, children: children || []});
const _jac = {builtin: {}, types: {}};
const sidebar = {toggled: 0};
const useState = (v) => [v, () => {}];
const useEffect = () => {};
const useCallback = (f) => f;
const createContext = (v) => ({Provider: "Provider"});
const useContext = () => ({toggleSidebar: () => { sidebar.toggled += 1; }});
const cva = () => () => "";
const cn = (...parts) => parts.filter(Boolean).join(" ");
const [Slot, HugeiconsIcon, SidebarLeftIcon, Button, Input, Separator, Sheet,
    SheetContent, SheetDescription, SheetHeader, SheetTitle, Skeleton, Tooltip,
    TooltipContent, TooltipTrigger] = Array(15).fill("stub");
function check(value, message) { if (!value) throw new Error(message); }
""";
    with TemporaryDirectory() as tmp {
        script = os.path.join(tmp, "component.mjs");
        with open(script, "w") as f {
            f.write(stubs + js + checks);
        }
        result = subprocess.run(
            [bun, script], capture_output=True, text=True, timeout=30
        );
        assert result.returncode == 0 , result.stdout + result.stderr;
    }
}

test "SidebarProvider keeps the caller's style next to its width defaults" {
    run_component(
        "sidebar.jac",
        """
const wrapper = SidebarProvider({style: {color: "red", "--sidebar-width": "20rem"}}).children[0];
check(wrapper.props.style.color === "red", "caller style dropped");
check(wrapper.props.style["--sidebar-width"] === "20rem", "caller cannot set the width");
check(wrapper.props.style["--sidebar-width-icon"] === "3rem", "default icon width lost");
const plain = SidebarProvider({}).children[0];
check(plain.props.style["--sidebar-width"] === "16rem", "default width lost");
"""
    );
}

test "SidebarTrigger runs the caller's click handler and toggles the sidebar" {
    run_component(
        "sidebar.jac",
        """
let clicked = 0;
const trigger = SidebarTrigger({onClick: () => { clicked += 1; }, className: "mine"});
trigger.props.onClick({});
check(clicked === 1, "caller onClick not called");
check(sidebar.toggled === 1, "sidebar not toggled");
check(trigger.props.className === "cn-sidebar-trigger mine", "className not merged");
"""
    );
}
