import os;
import time;
import shutil;
import tempfile;
import subprocess;

glob ROLE_ORDER: list[str] = [
         "foundation",
         "hub",
         "integrator",
         "entry",
         "relay",
         "leaf",
         "isolated"
     ],
     ROLE_TEXT: dict[str, str] = {
         "foundation": "feeds many modules and pulls from few: read these first",
         "hub": "feeds many and pulls from many: central, and risky to change",
         "integrator": "pulls from many modules and feeds few",
         "entry": "nothing in the project wires to it: an entry point, a test, or code loaded by name",
         "relay": "a few wires in and out",
         "leaf": "feeds a few modules and pulls from none",
         "isolated": "no wires at all"
     },
     WHOLE: str = "(whole module)",
     MAX_LIST: int = 12;

obj ModuleRole {
    has key: str,
        role: str = "relay",
        consumers: int = 0,
        providers: int = 0,
        names_out: int = 0,
        names_in: int = 0;
}

obj RolesReport {
    has scope: str,
        roles: list[ModuleRole] = [],
        hi_in: int = 0,
        hi_out: int = 0;

    def by_role(role: str) -> list[ModuleRole];
}

obj CrossName {
    has provider: str,
        name: str,
        others: list[str] = [];
}

obj InterfaceReport {
    has key: str,
        exports: list[CrossName] = [],
        imports: list[CrossName] = [],
        out_by_group: dict[str, int] = {},
        in_by_group: dict[str, int] = {},
        out_wires: int = 0,
        in_wires: int = 0,
        hints: list[str] = [];
}

obj RuleArm {
    has source: str,
        target: str,
        wires: int = 0;
}

obj RuleUse {
    has key: str,
        name: str,
        archwire: str = "",
        sources: list[str] = [],
        targets: list[str] = [],
        names: list[str] = [],
        wires: int = 0,
        governs: int = 0,
        arms: list[RuleArm] = [],
        unused_names: list[str] = [];
}

obj IntentReport {
    has rules: list[RuleUse] = [],
        violations: dict[str, list[WireInfo]] = {},
        crossing: int = 0,
        admitted: int = 0;

    def dead_rules -> list[RuleUse];
    def unused_arms -> list[tuple[RuleUse, RuleArm]];
    def thin_arms -> list[tuple[RuleUse, RuleArm]];
}

obj Reach {
    has key: str,
        direction: str,
        seeds: list[str] = [],
        name: str = "",
        depth: dict[str, int] = {},
        direct: list[WireInfo] = [],
        eager: int = -1,
        eager_steps: list[list[str]] = [];

    def modules -> set[str];
    def at(d: int) -> list[str];
    def max_depth -> int;
}

obj Cluster {
    has id: int,
        members: list[str] = [],
        by_group: dict[str, int] = {},
        label: str = "",
        share: float = 0.0;
}

obj Misplaced {
    has key: str,
        home: str,
        best: str,
        own_share: float = 0.0,
        best_share: float = 0.0,
        wires: int = 0;
}

obj ClusterReport {
    has scope: str,
        clusters: list[Cluster] = [],
        misplaced: list[Misplaced] = [],
        split: list[tuple[str, list[tuple[int, int]]]] = [],
        merged: list[Cluster] = [],
        purity: float = 0.0,
        modularity: float = 0.0,
        modules: int = 0;
}

obj LevelDelta {
    has scope: str,
        back_before: int = 0,
        back_after: int = 0,
        new_back: list[tuple[str, str, int]] = [],
        gone_back: list[tuple[str, str, int]] = [],
        cycle_before: int = 0,
        cycle_after: int = 0,
        viol_before: int = 0,
        viol_after: int = 0,
        iface: list[tuple[str, int, int]] = [],
        is_new: bool = False,
        groups: int = 0,
        wires: int = 0;

    def changed -> bool;
}

obj ArchDiff {
    has base: str,
        error: str = "",
        added: list[WireInfo] = [],
        removed: list[WireInfo] = [],
        names_added: list[tuple[WireInfo, list[str]]] = [],
        names_removed: list[tuple[WireInfo, list[str]]] = [],
        rules_added: list[str] = [],
        rules_removed: list[str] = [],
        rules_changed: list[str] = [],
        rule_changes: dict[str, list[str]] = {},
        forms_changed: list[tuple[WireInfo, str, str]] = [],
        new_violations: list[WireInfo] = [],
        fixed_violations: list[WireInfo] = [],
        levels: list[LevelDelta] = [],
        secs: float = 0.0;
}

def wire_names(w: WireInfo) -> list[str];

def project_keys(model: ProjectModel) -> set[str];

def outside_label(key: str, inside: str) -> str;

def module_roles(model: ProjectModel, scope: str = "") -> RolesReport;

def roles_text(rep: RolesReport) -> str;

def roles_dict(rep: RolesReport) -> dict[str, any];

def interface_of(model: ProjectModel, key: str) -> InterfaceReport;

def interface_text(rep: InterfaceReport) -> str;

def interface_dict(rep: InterfaceReport) -> dict[str, any];

def intent_report(model: ProjectModel) -> IntentReport;

def intent_text(rep: IntentReport, model: ProjectModel) -> str;

def intent_dict(rep: IntentReport) -> dict[str, any];

def seeds_for(model: ProjectModel, key: str) -> tuple[list[str], str];

def reach(
    model: ProjectModel,
    key: str,
    direction: str,
    max_depth: int = 0,
    eager_only: bool = False
) -> Reach;

def reach_text(r: Reach, model: ProjectModel) -> str;

def reach_dict(r: Reach) -> dict[str, any];

def louvain(nodes: list[str], weights: dict[tuple[str, str], float]) -> dict[str, int];

def louvain_pass(adj: list[dict[int, float]], n: int) -> tuple[list[int], bool];

def cluster_report(model: ProjectModel, scope: str = "") -> ClusterReport;

def clusters_text(rep: ClusterReport) -> str;

def clusters_dict(rep: ClusterReport) -> dict[str, any];

def tour_text(model: ProjectModel, scope: str = "") -> str;

def model_at_rev(
    model: ProjectModel, rev: str
) -> tuple[(ProjectModel | None), str, str];

def review_base(where: str, rev: str) -> str;

def level_delta(before: ProjectModel, after: ProjectModel, scope: str) -> LevelDelta;

def arch_diff(model: ProjectModel, rev: str) -> ArchDiff;

def diff_text(d: ArchDiff) -> str;

def diff_dict(d: ArchDiff) -> dict[str, any];

def default_base(where: str) -> str;

def insight_run(model: ProjectModel, view: str, key: str, as_text: bool) -> any;

def filter_modules(model: ProjectModel, spec: str) -> (set[str] | None);

def filter_label(spec: str) -> str;

def spec_parts(spec: str) -> dict[str, str];

impl RolesReport.by_role(role: str) -> list[ModuleRole] {
    return [
        r
        for r in self.roles
        if r.role == role
    ];
}

impl IntentReport.dead_rules -> list[RuleUse] {
    return [
        r
        for r in self.rules
        if r.wires == 0
    ];
}

impl IntentReport.unused_arms -> list[tuple[RuleUse, RuleArm]] {
    out: list[tuple[RuleUse, RuleArm]] = [];
    for r in self.rules {
        if r.wires == 0 {
            continue;
        }
        for a in r.arms {
            if a.wires == 0 {
                out.append((r, a));
            }
        }
    }
    return out;
}

impl IntentReport.thin_arms -> list[tuple[RuleUse, RuleArm]] {
    out: list[tuple[RuleUse, RuleArm]] = [];
    for r in self.rules {
        for a in r.arms {
            if a.wires == 1 {
                out.append((r, a));
            }
        }
    }
    return out;
}

impl Reach.modules -> set[str] {
    return set(self.depth.keys());
}

impl Reach.at(d: int) -> list[str] {
    return sorted(
        [
            k
            for (k, v) in self.depth.items()
            if v == d
        ]
    );
}

impl Reach.max_depth -> int {
    return max(list(self.depth.values()) + [0]);
}

impl LevelDelta.changed -> bool {
    return bool(
        self.is_new
            or self.new_back
            or self.gone_back
            or self.cycle_before != self.cycle_after
            or self.viol_before != self.viol_after
            or self.iface
    );
}

impl wire_names(w: WireInfo) -> list[str] {
    return [n.split(" as ")[0].strip() for n in w.names] if w.names else [WHOLE];
}

impl project_keys(model: ProjectModel) -> set[str] {
    return {
        k
        for (k, m) in model.modules.items()
        if m.kind == "module"
    };
}

impl outside_label(key: str, inside: str) -> str {
    a = key.split(".");
    b = inside.split(".");
    n = 0;
    while n < min(len(a), len(b)) and a[n] == b[n] {
        n += 1;
    }
    return ".".join(a[:n + 1]);
}

impl module_roles(model: ProjectModel, scope: str = "") -> RolesReport {
    with model.lock {
        keys = project_keys(model);
        cons: dict[str, set[str]] = {k: set() for k in keys};
        provs: dict[str, set[str]] = {k: set() for k in keys};
        names_out: dict[str, set[str]] = {k: set() for k in keys};
        names_in: dict[str, set[str]] = {k: set() for k in keys};
        for w in model.wires {
            if w.provider not in keys
                or w.consumer not in keys
                or w.provider == w.consumer {
                continue;
            }
            cons[w.provider].add(w.consumer);
            provs[w.consumer].add(w.provider);
            for n in wire_names(w) {
                names_out[w.provider].add(n);
                names_in[w.consumer].add(f"{w.provider}.{n}");
            }
        }
    }
    wired = sorted(
        [
            k
            for k in keys
            if cons[k] or provs[k]
        ]
    );
    ins = sorted([len(cons[k]) for k in wired]);
    outs = sorted([len(provs[k]) for k in wired]);
    hi_in = max(4, ins[int(len(ins) * 0.9)] if ins else 0);
    hi_out = max(4, outs[int(len(outs) * 0.9)] if outs else 0);
    rep = RolesReport(scope=scope, hi_in=hi_in, hi_out=hi_out);
    for k in sorted(keys) {
        if not in_scope(k, scope) {
            continue;
        }
        (c, p) = (len(cons[k]), len(provs[k]));
        role = "relay";
        if c == 0 and p == 0 {
            role = "isolated";
        } elif c == 0 {
            role = "entry";
        } elif c >= hi_in and p >= hi_out {
            role = "hub";
        } elif c >= hi_in {
            role = "foundation";
        } elif p >= hi_out {
            role = "integrator";
        } elif p == 0 {
            role = "leaf";
        }
        rep.roles.append(
            ModuleRole(
                key=k,
                role=role,
                consumers=c,
                providers=p,
                names_out=len(names_out[k]),
                names_in=len(names_in[k])
            )
        );
    }
    rep.roles.sort(
        key=lambda (r: ModuleRole) -> tuple[int, int, str] { (
            ROLE_ORDER.index(r.role),
            -(r.consumers + r.providers),
            r.key
        ) }
    );
    return rep;
}

impl roles_text(rep: RolesReport) -> str {
    lines = [
        f"Roles of the {len(rep.roles)} modules in {rep.scope or 'the project'} "
            + f"(many = {rep.hi_in}+ consumers or {rep.hi_out}+ providers, the top tenth of the project):"
    ];
    for role in ROLE_ORDER {
        group = rep.by_role(role);
        if not group {
            continue;
        }
        lines.append("");
        lines.append(f"{role} ({len(group)}): {ROLE_TEXT[role]}");
        for r in group[:MAX_LIST] {
            lines.append(
                f"  {r.key}  feeds {r.consumers}, fed by {r.providers}, provides {r.names_out} name(s)"
            );
        }
        if len(group) > MAX_LIST {
            lines.append(f"  ... and {len(group) - MAX_LIST} more");
        }
    }
    return "\n".join(lines);
}

impl roles_dict(rep: RolesReport) -> dict[str, any] {
    return {
        "scope": rep.scope,
        "thresholds": {"consumers": rep.hi_in, "providers": rep.hi_out},
        "counts": {r: len(rep.by_role(r)) for r in ROLE_ORDER},
        "modules": [
            {
                "key": r.key,
                "role": r.role,
                "consumers": r.consumers,
                "providers": r.providers,
                "names_out": r.names_out,
                "names_in": r.names_in
            } for r in rep.roles
        ]
    };
}

impl interface_of(model: ProjectModel, key: str) -> InterfaceReport {
    rep = InterfaceReport(key=key);
    out_map: dict[tuple[str, str], set[str]] = {};
    in_map: dict[tuple[str, str], set[str]] = {};
    with model.lock {
        keys = project_keys(model);
        for w in model.wires {
            if w.provider not in keys or w.consumer not in keys {
                continue;
            }
            p_in = in_scope(w.provider, key);
            c_in = in_scope(w.consumer, key);
            if p_in and not c_in {
                rep.out_wires += 1;
                g = outside_label(w.consumer, key);
                rep.out_by_group[g] = rep.out_by_group.get(g, 0) + 1;
                for n in wire_names(w) {
                    out_map.setdefault((w.provider, n), set()).add(w.consumer);
                }
            } elif c_in and not p_in {
                rep.in_wires += 1;
                g = outside_label(w.provider, key);
                rep.in_by_group[g] = rep.in_by_group.get(g, 0) + 1;
                for n in wire_names(w) {
                    in_map.setdefault((w.provider, n), set()).add(w.consumer);
                }
            }
        }
    }
    for ((p, n), users) in out_map.items() {
        rep.exports.append(CrossName(provider=p, name=n, others=sorted(users)));
    }
    for ((p, n), users) in in_map.items() {
        rep.imports.append(CrossName(provider=p, name=n, others=sorted(users)));
    }
    rep.exports.sort(
        key=lambda (c: CrossName) -> tuple[int, str] { (-len(c.others), c.name) }
    );
    rep.imports.sort(
        key=lambda (c: CrossName) -> tuple[int, str] { (-len(c.others), c.name) }
    );
    single = [
        c
        for c in rep.exports
        if len(c.others) == 1 and c.name != WHOLE
    ];
    if single {
        sample = ", ".join([f"{c.name} (only {c.others[0]})" for c in single[:5]]);
        rep.hints.append(
            f"{len(single)} of {len(
                rep.exports
            )} exported names have a single outside user"
                + (
                    ", so most of the surface is bespoke"
                        if len(single) * 2 > len(rep.exports)
                        else ""
                )
                + f"; such a name could live next to its user: {sample}"
        );
    }
    wide = [
        c
        for c in rep.exports
        if len(c.others) >= 8 and c.name != WHOLE
    ];
    if wide {
        rep.hints.append(
            "Core abstractions, used by 8+ outside modules: "
                + ", ".join([f"{c.name} ({len(c.others)})" for c in wide[:8]])
        );
    }
    if rep.out_wires >= 5 and rep.out_by_group {
        (top, cnt) = sorted(
            rep.out_by_group.items(), key=lambda (kv: tuple[str, int]) -> int { -kv[1] }
        )[0];
        share = cnt / rep.out_wires;
        if share >= 0.75 and len(rep.out_by_group) > 1 or share >= 0.9 {
            rep.hints.append(
                f"{int(share * 100)}% of what {key} exports goes to {top}: it serves {top} and little else"
            );
        }
    }
    if not rep.exports and rep.imports {
        rep.hints.append(
            f"Nothing outside {key} uses it: it only consumes (an entry point or an app)"
        );
    }
    return rep;
}

impl interface_text(rep: InterfaceReport) -> str {
    lines = [
        f"Interface of {rep.key}: {len(rep.exports)} name(s) leave it over {rep.out_wires} wire(s); "
            + f"{len(rep.imports)} name(s) enter over {rep.in_wires} wire(s)."
    ];
    for h in rep.hints {
        lines.append(f"* {h}");
    }
    if rep.exports {
        lines.append("");
        lines.append("Exports (name: outside users):");
        for c in rep.exports[:40] {
            more = f" +{len(c.others) - 4}" if len(c.others) > 4 else "";
            lines.append(
                f"  {c.provider}.{c.name}: {len(c.others)}  ({', '.join(c.others[:4])}{more})"
            );
        }
        if len(rep.exports) > 40 {
            lines.append(f"  ... and {len(rep.exports) - 40} more");
        }
        lines.append(
            "Exported to: "
                + ", ".join(
                    [
                        f"{g} {n}"
                        for (g, n) in sorted(
                            rep.out_by_group.items(),
                            key=lambda (kv: tuple[str, int]) -> int { -kv[1] }
                        )
                    ]
                )
        );
    }
    if rep.imports {
        lines.append("");
        lines.append(
            "Imported from: "
                + ", ".join(
                    [
                        f"{g} {n}"
                        for (g, n) in sorted(
                            rep.in_by_group.items(),
                            key=lambda (kv: tuple[str, int]) -> int { -kv[1] }
                        )
                    ]
                )
        );
        for c in rep.imports[:20] {
            lines.append(
                f"  {c.provider}.{c.name}: used by {len(c.others)} module(s) inside"
            );
        }
    }
    return "\n".join(lines);
}

impl interface_dict(rep: InterfaceReport) -> dict[str, any] {
    return {
        "key": rep.key,
        "hints": rep.hints,
        "exports": [
            {"provider": c.provider, "name": c.name, "users": c.others}
            for c in rep.exports
        ],
        "imports": [
            {"provider": c.provider, "name": c.name, "users": c.others}
            for c in rep.imports
        ],
        "exported_to": rep.out_by_group,
        "imported_from": rep.in_by_group,
        "wires_out": rep.out_wires,
        "wires_in": rep.in_wires
    };
}

impl intent_report(model: ProjectModel) -> IntentReport {
    rep = IntentReport();
    with model.lock {
        by_rule: dict[str, list[WireInfo]] = {r.key: [] for r in model.rules};
        for w in model.wires {
            if w.crosses {
                rep.crossing += 1;
                if w.rules {
                    rep.admitted += 1;
                }
            }
            for rk in w.rules {
                if rk in by_rule {
                    by_rule[rk].append(w);
                }
            }
            if w.violation {
                code = w.violation.split(" ")[0];
                rep.violations.setdefault(code, []).append(w);
            }
        }
        for r in model.rules {
            rec = model.rule_recs.get(r.key);
            used = by_rule.get(r.key, []);
            ru = RuleUse(
                key=r.key,
                name=r.name,
                archwire=r.file,
                sources=r.sources,
                targets=r.targets,
                names=r.names,
                wires=len(used),
                governs=len([m for m in [r->:Governs:->]])
            );
            if rec is not None {
                for sp_ in rec.sources {
                    for tp in rec.targets {
                        arm = RuleArm(source=sp_.text, target=tp.text);
                        for w in used {
                            if sp_.matches(w.local_provider)
                                and tp.matches(w.local_consumer) {
                                arm.wires += 1;
                            }
                        }
                        ru.arms.append(arm);
                    }
                }
            }
            if r.names {
                carried: set[str] = set();
                for w in used {
                    carried.update(wire_names(w));
                }
                ru.unused_names = sorted(
                    [
                        n
                        for n in r.names
                        if n not in carried
                    ]
                );
            }
            rep.rules.append(ru);
        }
    }
    rep.rules.sort(key=lambda (r: RuleUse) -> int { -r.wires });
    return rep;
}

impl intent_text(rep: IntentReport, model: ProjectModel) -> str {
    pct = int(100 * rep.admitted / rep.crossing) if rep.crossing else 100;
    nviol = sum([len(v) for v in rep.violations.values()]);
    lines = [
        f"Intent vs reality: {len(rep.rules)} rule(s); {rep.crossing} wire(s) cross a package boundary and {rep.admitted} ({pct}%) are admitted by a rule; {nviol} violate one."
    ];
    lines.append("");
    lines.append("Rules by use (wires admitted, modules governed):");
    for r in rep.rules {
        payload = f" {{ {', '.join(r.names)} }}" if r.names else "";
        lines.append(
            f"  {r.name}: {' | '.join(r.sources)} --> {' | '.join(r.targets)}{payload}  [{r.wires} wires, governs {r.governs}]"
        );
        idle = [
            a.target
            for a in r.arms
            if a.wires == 0
        ];
        if idle and r.wires {
            lines.append(f"      never used toward: {', '.join(idle)}");
        }
        if r.unused_names {
            lines.append(
                f"      payload names nothing carries: {', '.join(r.unused_names)}"
            );
        }
    }
    dead = rep.dead_rules();
    if dead {
        lines.append("");
        lines.append(
            "Rules no wire uses (the permission could be removed): "
                + ", ".join([r.name for r in dead])
        );
    }
    unused = rep.unused_arms();
    arms = sum([len(r.arms) for r in rep.rules]);
    if not unused and arms >= 10 {
        lines.append("");
        lines.append(
            f"Every one of the {arms} source->target permissions is used by at least one wire: the rules mirror the current wiring (as rules generated from it do), so they record dependencies rather than limit them. Tightening starts with the permissions a single wire uses."
        );
    }
    if unused {
        lines.append(
            f"Permissions never used ({len(unused)} source->target pairs): "
                + ", ".join([f"{a.source}->{a.target}" for (r, a) in unused[:16]])
                + (" ..." if len(unused) > 16 else "")
        );
    }
    thin = rep.thin_arms();
    if thin {
        lines.append(
            f"Permissions used by exactly one wire ({len(thin)}): "
                + ", ".join(
                    [f"{a.source}->{a.target} ({r.name})" for (r, a) in thin[:12]]
                )
                + (" ..." if len(thin) > 12 else "")
        );
    }
    if rep.violations {
        lines.append("");
        lines.append("Violations:");
        for (code, ws) in sorted(rep.violations.items()) {
            lines.append(f"  {code} ({len(ws)}):");
            for w in ws[:10] {
                lines.append(f"    {w.provider} ++> {w.consumer}: {w.violation}");
            }
        }
    }
    return "\n".join(lines);
}

impl intent_dict(rep: IntentReport) -> dict[str, any] {
    return {
        "crossing_wires": rep.crossing,
        "admitted_wires": rep.admitted,
        "rules": [
            {
                "name": r.name,
                "archwire": r.archwire,
                "sources": r.sources,
                "targets": r.targets,
                "names": r.names,
                "wires": r.wires,
                "governs": r.governs,
                "arms": [
                    {"source": a.source, "target": a.target, "wires": a.wires}
                    for a in r.arms
                ],
                "unused_names": r.unused_names
            } for r in rep.rules
        ],
        "violations": {
            code: [w.to_dict() for w in ws] for (code, ws) in rep.violations.items()
        }
    };
}

impl seeds_for(model: ProjectModel, key: str) -> tuple[list[str], str] {
    keys = project_keys(model);
    if key in keys {
        return ([key], "");
    }
    inside = sorted(
        [
            k
            for k in keys
            if in_scope(k, key)
        ]
    );
    if inside {
        return (inside, "");
    }
    parts = key.split(".");
    for i in range(len(parts) - 1, 0, -1) {
        mod = ".".join(parts[:i]);
        if mod in keys {
            return ([mod], parts[i]);
        }
    }
    return ([], "");
}

impl reach(
    model: ProjectModel,
    key: str,
    direction: str,
    max_depth: int = 0,
    eager_only: bool = False
) -> Reach {
    (seeds, name) = seeds_for(model, key);
    r = Reach(key=key, direction=direction, seeds=seeds, name=name);
    with model.lock {
        keys = project_keys(model);
        nxt: dict[str, list[tuple[str, WireInfo]]] = {};
        for w in model.wires {
            if w.provider not in keys
                or w.consumer not in keys
                or w.provider == w.consumer {
                continue;
            }
            if eager_only and w.scope {
                continue;
            }
            if direction == "down" {
                nxt.setdefault(w.provider, []).append((w.consumer, w));
            } else {
                nxt.setdefault(w.consumer, []).append((w.provider, w));
            }
        }
    }
    for s in seeds {
        r.depth[s] = 0;
    }
    frontier = list(seeds);
    d = 0;
    while frontier and (max_depth <= 0 or d < max_depth) {
        d += 1;
        found: list[str] = [];
        for cur in frontier {
            for (other, w) in nxt.get(cur, []) {
                if d == 1
                    and name
                    and direction == "down"
                    and name not in wire_names(w) {
                    continue;
                }
                if d == 1 {
                    if other not in r.depth or r.depth[other] == 1 {
                        r.direct.append(w);
                    }
                }
                if other not in r.depth {
                    r.depth[other] = d;
                    found.append(other);
                }
            }
        }
        frontier = found;
    }
    if not eager_only and max_depth <= 0 {
        er = reach(model, key, direction, 0, True);
        r.eager = len(er.depth) - len(seeds);
        r.eager_steps = [er.at(d) for d in range(1, er.max_depth() + 1)];
    }
    return r;
}

impl reach_text(r: Reach, model: ProjectModel) -> str {
    if not r.seeds {
        return f"No module matches {r.key}.";
    }
    what = f"{r.key}" + (f" (the name {r.name} in {r.seeds[0]})" if r.name else "");
    total = len(r.depth) - len(r.seeds);
    direct = len(r.at(1));
    lines: list[str] = [];
    if r.direction == "down" {
        lines.append(f"Blast radius of {what}:");
        lines.append(
            f"  {direct} module(s) use it directly"
                + (f" (exact: the wires that carry {r.name})" if r.name else "")
                + "."
        );
        if r.eager >= 0 {
            lines.append(
                f"  {r.eager} module(s) load it when they load, through module-level wires."
            );
        }
        lines.append(
            f"  {total} module(s) can reach it at all, counting wires that import inside a function (an upper bound)."
        );
    } else {
        lines.append(f"Slice of {what}:");
        lines.append(f"  it uses {direct} module(s) directly.");
        if r.eager >= 0 {
            lines.append(
                f"  importing it loads {r.eager} module(s), through module-level wires."
            );
        }
        lines.append(
            f"  running all of it can reach {total} module(s), counting wires that import inside a function."
        );
    }
    def step_line(d: int, mods: list[str]) -> str {
        by_group: dict[str, int] = {};
        for m in mods {
            g = outside_label(m, r.seeds[0]) if not in_scope(m, r.seeds[0]) else m;
            by_group[g] = by_group.get(g, 0) + 1;
        }
        top = sorted(
            by_group.items(), key=lambda (kv: tuple[str, int]) -> int { -kv[1] }
        );
        return f"  step {d}: {len(mods)} module(s)  "
            + ", ".join([f"{g} {n}" for (g, n) in top[:8]])
            + (" ..." if len(top) > 8 else "");
    }
    if r.eager_steps {
        lines.append("");
        lines.append("Loaded at import time, by step:");
        for (i, mods) in enumerate(r.eager_steps) {
            lines.append(step_line(i + 1, mods));
        }
    }
    if total > r.eager {
        lines.append("");
        lines.append("Reachable through any wire, by step:");
        for d in range(1, r.max_depth() + 1) {
            lines.append(step_line(d, r.at(d)));
        }
    }
    if r.direct {
        lines.append("");
        lines.append("Direct wires:");
        for w in r.direct[:30] {
            names = ", ".join(w.names) if w.names else WHOLE;
            where = f" (in {w.scope})" if w.scope else "";
            lines.append(f"  {w.provider} ++> {w.consumer}{where} {{ {names} }}");
        }
        if len(r.direct) > 30 {
            lines.append(f"  ... and {len(r.direct) - 30} more");
        }
    }
    return "\n".join(lines);
}

impl reach_dict(r: Reach) -> dict[str, any] {
    return {
        "key": r.key,
        "direction": r.direction,
        "seeds": r.seeds,
        "name": r.name,
        "steps": [r.at(d) for d in range(1, r.max_depth() + 1)],
        "eager": r.eager,
        "eager_steps": r.eager_steps,
        "direct": [w.to_dict() for w in r.direct]
    };
}

impl louvain_pass(adj: list[dict[int, float]], n: int) -> tuple[list[int], bool] {
    k = [sum(adj[i].values()) for i in range(n)];
    m2 = sum(k);
    comm = list(range(n));
    if m2 == 0 {
        return (comm, False);
    }
    tot = list(k);
    moved = False;
    improved = True;
    rounds = 0;
    while improved and rounds < 25 {
        improved = False;
        rounds += 1;
        for i in range(n) {
            ci = comm[i];
            links: dict[int, float] = {};
            for (j, wt) in adj[i].items() {
                if j != i {
                    links[comm[j]] = links.get(comm[j], 0.0) + wt;
                }
            }
            tot[ci] -= k[i];
            best = ci;
            best_gain = links.get(ci, 0.0) - tot[ci] * k[i] / m2;
            for c in sorted(links.keys()) {
                gain = links[c] - tot[c] * k[i] / m2;
                if gain > best_gain + 1e-12 {
                    (best, best_gain) = (c, gain);
                }
            }
            tot[best] += k[i];
            if best != ci {
                comm[i] = best;
                improved = True;
                moved = True;
            }
        }
    }
    return (comm, moved);
}

impl louvain(
    nodes: list[str], weights: dict[tuple[str, str], float]
) -> dict[str, int] {
    n = len(nodes);
    idx = {nd: i for (i, nd) in enumerate(nodes)};
    adj: list[dict[int, float]] = [{} for _ in range(n)];
    for ((a, b), wt) in weights.items() {
        if a == b or a not in idx or b not in idx {
            continue;
        }
        (i, j) = (idx[a], idx[b]);
        adj[i][j] = adj[i].get(j, 0.0) + wt;
        adj[j][i] = adj[j].get(i, 0.0) + wt;
    }
    mapping = list(range(n));
    cur = adj;
    cur_n = n;
    for _ in range(12) {
        (comm, moved) = louvain_pass(cur, cur_n);
        if not moved {
            break;
        }
        ids: dict[int, int] = {};
        for c in comm {
            if c not in ids {
                ids[c] = len(ids);
            }
        }
        comm = [ids[c] for c in comm];
        mapping = [comm[mapping[i]] for i in range(n)];
        agg: list[dict[int, float]] = [{} for _ in range(len(ids))];
        for i in range(cur_n) {
            for (j, wt) in cur[i].items() {
                agg[comm[i]][comm[j]] = agg[comm[i]].get(comm[j], 0.0) + wt;
            }
        }
        cur = agg;
        cur_n = len(ids);
    }
    return {nodes[i]: mapping[i] for i in range(n)};
}

impl cluster_report(model: ProjectModel, scope: str = "") -> ClusterReport {
    scope = effective_scope(model, scope);
    rep = ClusterReport(scope=scope);
    weights: dict[tuple[str, str], float] = {};
    touch: dict[str, dict[str, int]] = {};
    fed_to: dict[str, dict[str, int]] = {};
    with model.lock {
        keys = {
            k
            for k in project_keys(model)
            if in_scope(k, scope)
        };
        for w in model.wires {
            (a, b) = (w.provider, w.consumer);
            if a == b or a not in keys or b not in keys {
                continue;
            }
            pair = (a, b) if a < b else (b, a);
            weights[pair] = weights.get(pair, 0.0) + 1.0;
            ga = group_of(a, scope);
            gb = group_of(b, scope);
            touch.setdefault(a, {})[gb] = touch.setdefault(a, {}).get(gb, 0) + 1;
            touch.setdefault(b, {})[ga] = touch.setdefault(b, {}).get(ga, 0) + 1;
            fed_to.setdefault(a, {})[gb] = fed_to.setdefault(a, {}).get(gb, 0) + 1;
        }
    }
    nodes = sorted({k for pair in weights.keys() for k in pair});
    rep.modules = len(nodes);
    if not nodes {
        return rep;
    }
    comm = louvain(nodes, weights);
    members: dict[int, list[str]] = {};
    for nd in nodes {
        members.setdefault(comm[nd], []).append(nd);
    }
    total_w = sum(weights.values());
    deg: dict[int, float] = {};
    inner: dict[int, float] = {};
    for ((a, b), wt) in weights.items() {
        deg[comm[a]] = deg.get(comm[a], 0.0) + wt;
        deg[comm[b]] = deg.get(comm[b], 0.0) + wt;
        if comm[a] == comm[b] {
            inner[comm[a]] = inner.get(comm[a], 0.0) + wt;
        }
    }
    rep.modularity = sum(
        [
            inner.get(c, 0.0) / total_w - (deg.get(c, 0.0) / (2 * total_w)) ** 2
            for c in members.keys()
        ]
    );
    pure = 0;
    group_size: dict[str, int] = {};
    for nd in nodes {
        g = group_of(nd, scope);
        group_size[g] = group_size.get(g, 0) + 1;
    }
    for (cid, ms) in members.items() {
        cl = Cluster(id=cid, members=sorted(ms));
        for m in ms {
            g = group_of(m, scope);
            cl.by_group[g] = cl.by_group.get(g, 0) + 1;
        }
        (cl.label, top) = sorted(
            cl.by_group.items(), key=lambda (kv: tuple[str, int]) -> int { -kv[1] }
        )[0];
        cl.share = top / len(ms);
        pure += top;
        rep.clusters.append(cl);
        big = [
            g
            for (g, c) in cl.by_group.items()
            if c >= 0.25 * len(ms)
        ];
        if len(ms) >= 6 and (len(big) >= 2 or cl.share < 0.5) {
            rep.merged.append(cl);
        }
    }
    rep.clusters.sort(key=lambda (c: Cluster) -> int { -len(c.members) });
    for (i, cl) in enumerate(rep.clusters) {
        cl.id = i + 1;
    }
    rep.purity = pure / len(nodes);
    for (g, size) in group_size.items() {
        if size < 6 {
            continue;
        }
        parts = sorted(
            [
                (cl.id, cl.by_group.get(g, 0))
                for cl in rep.clusters
                if cl.by_group.get(g, 0) >= 0.2 * size
            ],
            key=lambda (p: tuple[int, int]) -> int { -p[1] }
        );
        if len(parts) >= 2 and parts[0][1] < 0.6 * size {
            rep.split.append((g, parts));
        }
    }
    for nd in nodes {
        home = group_of(nd, scope);
        if group_size.get(home, 0) < 2 or nd == home {
            continue;
        }
        t = touch.get(nd, {});
        total = sum(t.values());
        feeds = fed_to.get(nd, {});
        fed_total = sum(feeds.values());
        if total < 4 or fed_total < 3 {
            continue;
        }
        own_share = t.get(home, 0) / total;
        others = sorted(
            [
                (g, c)
                for (g, c) in feeds.items()
                if g != home
            ],
            key=lambda (kv: tuple[str, int]) -> int { -kv[1] }
        );
        if not others {
            continue;
        }
        (best, cnt) = others[0];
        best_share = cnt / fed_total;
        if own_share < 0.3 and best_share >= 0.7 {
            rep.misplaced.append(
                Misplaced(
                    key=nd,
                    home=home,
                    best=best,
                    own_share=own_share,
                    best_share=best_share,
                    wires=total
                )
            );
        }
    }
    rep.misplaced.sort(key=lambda (m: Misplaced) -> int { -m.wires });
    return rep;
}

impl clusters_text(rep: ClusterReport) -> str {
    def short(g: str) -> str {
        return g[len(rep.scope) + 1:]
            if rep.scope and g.startswith(rep.scope + ".")
            else g;
    }
    lines = [
        f"Natural clusters of {rep.scope or 'the project'}: {rep.modules} wired module(s) fall into {len(
            rep.clusters
        )} cluster(s) "
            + f"(modularity {rep.modularity:.2f}); {int(
                rep.purity * 100
            )}% of modules sit in a cluster led by their own package."
    ];
    lines.append("");
    lines.append("Largest clusters (members by declared package):");
    for cl in [
        c
        for c in rep.clusters
        if len(c.members) > 2
    ][:15] {
        comp = sorted(
            cl.by_group.items(), key=lambda (kv: tuple[str, int]) -> int { -kv[1] }
        );
        lines.append(
            f"  {cl.id:>2}. {len(cl.members)} modules, {int(cl.share * 100)}% {short(
                cl.label
            )}: "
                + ", ".join([f"{short(g)} {n}" for (g, n) in comp[:6]])
        );
    }
    if rep.split {
        lines.append("");
        lines.append("Packages the wiring splits in two or more (cluster: modules):");
        for (g, parts) in rep.split[:12] {
            lines.append(
                f"  {short(g)}: " + ", ".join([f"#{cid} {n}" for (cid, n) in parts])
            );
        }
    }
    if rep.merged {
        lines.append("");
        lines.append(
            "Clusters that span packages (the wiring treats them as one unit):"
        );
        for cl in rep.merged[:10] {
            big = [
                f"{short(g)} {n}"
                for (g, n) in sorted(
                    cl.by_group.items(),
                    key=lambda (kv: tuple[str, int]) -> int { -kv[1] }
                )
                if n >= 0.1 * len(cl.members)
            ];
            lines.append(f"  #{cl.id} ({len(cl.members)}): " + ", ".join(big));
        }
    }
    if rep.misplaced {
        lines.append("");
        lines.append(
            "Modules that look misplaced (most of what they feed is in another package, and little of their wiring is with their own):"
        );
        for m in rep.misplaced[:20] {
            lines.append(
                f"  {m.key}: {int(m.best_share * 100)}% of its consumer wires go to {short(
                    m.best
                )}; {int(m.own_share * 100)}% of its wires stay in {short(m.home)}"
            );
        }
    }
    return "\n".join(lines);
}

impl clusters_dict(rep: ClusterReport) -> dict[str, any] {
    return {
        "scope": rep.scope,
        "modules": rep.modules,
        "modularity": rep.modularity,
        "purity": rep.purity,
        "clusters": [
            {
                "id": cl.id,
                "members": cl.members,
                "by_package": cl.by_group,
                "lead": cl.label,
                "lead_share": cl.share
            } for cl in rep.clusters
        ],
        "split_packages": [
            {"package": g, "parts": [{"cluster": c, "modules": n} for (c, n) in parts]}
            for (g, parts) in rep.split
        ],
        "misplaced": [
            {
                "key": m.key,
                "package": m.home,
                "feeds_mostly": m.best,
                "own_share": m.own_share,
                "feeds_share": m.best_share
            } for m in rep.misplaced
        ]
    };
}

impl tour_text(model: ProjectModel, scope: str = "") -> str {
    level = graph_level(model, scope);
    roles = module_roles(model, level.scope);
    intent = intent_report(model);
    title = level.scope or os.path.basename(model.root_dir);
    mods = sum([nd.modules for nd in level.nodes]);
    lines = [f"# A tour of {title}", ""];
    found = {r: len(roles.by_role(r)) for r in ROLE_ORDER};
    lines.append(
        f"{title} has {mods} modules in {len(level.nodes)} groups, joined by {level.wires} wires between groups and {level.inner_wires} inside them. "
            + f"By how they are wired, {found['foundation']} modules are foundations, {found[
                'hub'
            ]} are hubs, {found['integrator']} integrate, and {found[
                'entry'
            ]} are entry points nothing else consumes."
    );
    lines.append("");
    lines.append("## Start reading here");
    lines.append("");
    lines.append(
        "The foundations: many modules depend on them and they depend on little."
    );
    lines.append("");
    for r in roles.by_role("foundation")[:8] {
        m = model.modules.get(r.key);
        doc = m.doc.strip().split("\n")[0] if m is not None and m.doc else "";
        lines.append(
            f"- `{r.key}`: feeds {r.consumers} modules" + (f". {doc}" if doc else "")
        );
    }
    hubs = roles.by_role("hub")[:6];
    if hubs {
        lines.append("");
        lines.append("The hubs: central to everything, so change them with care.");
        lines.append("");
        for r in hubs {
            lines.append(f"- `{r.key}`: feeds {r.consumers}, fed by {r.providers}");
        }
    }
    lines.append("");
    lines.append("## How it is layered");
    lines.append("");
    lines.append(
        "Groups in provider order. Layer 0 is fed by nothing at this level; each layer builds on the ones above it."
    );
    for (li, band) in enumerate(level.layers()) {
        if not band {
            continue;
        }
        lines.append("");
        lines.append(f"### Layer {li}");
        for nd in band {
            iface = interface_of(model, nd.key);
            outs = sorted(
                level.out_edges(nd.key), key=lambda (e: GraphEdge) -> int { -e.count() }
            )[:3];
            feeds = ", ".join([f"{level.label_of(e.dst)} ({e.count()})" for e in outs]);
            top_names = ", ".join(
                [
                    c.name
                    for c in iface.exports[:5]
                    if c.name != WHOLE
                ]
            );
            parts = [f"{nd.modules} module" + ("s" if nd.modules != 1 else "")];
            if nd.rules {
                parts.append("rules " + ", ".join(nd.rules));
            }
            if nd.cycle >= 0 {
                parts.append("in a cycle");
            }
            lines.append("");
            lines.append(f"**{nd.label}** ({'; '.join(parts)})");
            if feeds {
                lines.append(f"Feeds {feeds}.");
            }
            if top_names {
                lines.append(f"Most used names: {top_names}.");
            }
            entries = [
                r.key
                for r in roles.roles
                if r.role == "entry" and in_scope(r.key, nd.key)
            ];
            if entries {
                lines.append(
                    f"Entry points: {', '.join(['`' + e + '`' for e in entries[:4]])}"
                        + (
                            f" and {len(entries) - 4} more."
                                if len(entries) > 4
                                else "."
                        )
                );
            }
        }
    }
    back = level.back_edges();
    if back or level.cycles {
        lines.append("");
        lines.append("## Where the layering breaks");
        lines.append("");
        lines.append(
            f"{level.back_wires} of {level.wires} wires between groups run backwards, from a later group to an earlier one."
        );
        for e in back[:8] {
            lines.append(
                f"- {level.label_of(e.src)} feeds {level.label_of(e.dst)} through {e.count()} wires"
            );
        }
        for (ci, comp) in enumerate(level.cycles) {
            lines.append(
                f"- Cycle {ci + 1}: {', '.join([level.label_of(g) for g in comp])}"
            );
        }
    }
    if intent.rules {
        lines.append("");
        lines.append("## The rules");
        lines.append("");
        lines.append(
            "Archwire rules state which packages may feed which. The ones carrying the most wires:"
        );
        for r in intent.rules[:8] {
            lines.append(
                f"- **{r.name}**: {' | '.join(r.sources)} feeds {' | '.join(
                    r.targets[:6]
                )}"
                    + (" ..." if len(r.targets) > 6 else "")
                    + f" ({r.wires} wires)"
            );
        }
        dead = intent.dead_rules();
        if dead {
            lines.append(f"- Unused: {', '.join([r.name for r in dead])}");
        }
    }
    return "\n".join(lines);
}

impl review_base(where: str, rev: str) -> str {
    try {
        return subprocess.run(
            ["git", "-C", where, "merge-base", rev, "HEAD"],
            capture_output=True,
            text=True,
            check=True
        ).stdout.strip();
    } except Exception {
        return rev;
    }
}

impl model_at_rev(
    model: ProjectModel, rev: str
) -> tuple[(ProjectModel | None), str, str] {
    where = model.root_dir;
    try {
        top = subprocess.run(
            ["git", "-C", where, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True
        ).stdout.strip();
        subprocess.run(
            ["git", "-C", top, "rev-parse", "--verify", rev + "^{commit}"],
            capture_output=True,
            text=True,
            check=True
        );
    } except Exception {
        return (None, f"{rev} is not a commit in the repository around {where}", "");
    }
    rel = os.path.relpath(os.path.realpath(where), os.path.realpath(top));
    tmp = tempfile.mkdtemp(prefix="jac-hack-rev-");
    spec = "." if rel == "." else rel;
    try {
        listed = subprocess.run(
            ["git", "-C", top, "ls-tree", "-r", "--name-only", rev, "--", spec],
            capture_output=True,
            text=True,
            check=True
        ).stdout.split(
            "\n"
        );
    } except Exception {
        shutil.rmtree(tmp, ignore_errors=True);
        return (None, f"could not list the tree at {rev}", "");
    }
    patterns = [
        f":(glob){spec}/**/{tail}"
        for (tail, ends) in [
            ("*.jac", ".jac"),
            ("*.py", ".py"),
            ("jac.toml", "jac.toml")
        ]
        if any([name.endswith(ends) for name in listed])
    ];
    if not patterns {
        shutil.rmtree(tmp, ignore_errors=True);
        return (None, f"{rev} has no Jac files under {rel}", "");
    }
    archive = subprocess.Popen(
        ["git", "-C", top, "archive", "--format=tar", rev, "--"] + patterns,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL
    );
    untar = subprocess.run(
        ["tar", "-x", "-C", tmp], stdin=archive.stdout, capture_output=True
    );
    archive.wait();
    if archive.returncode != 0 or untar.returncode != 0 {
        shutil.rmtree(tmp, ignore_errors=True);
        return (None, f"could not read the tree at {rev}", "");
    }
    base_root = os.path.join(tmp, rel) if rel != "." else tmp;
    try {
        before = ProjectModel(root_dir=base_root);
        before.build(index=False);
    } except Exception as e {
        shutil.rmtree(tmp, ignore_errors=True);
        return (None, f"could not load the wiring at {rev}: {e}", "");
    }
    return (before, "", tmp);
}

impl level_delta(before: ProjectModel, after: ProjectModel, scope: str) -> LevelDelta {
    a = graph_level(before, scope);
    b = graph_level(after, scope);
    def order_of(g: str) -> int {
        return b.index.get(g, len(b.index) + a.index.get(g, 0));
    }
    old_back = 0;
    for e in a.edges.values() {
        if order_of(e.src) > order_of(e.dst) {
            old_back += e.count();
        }
    }
    d = LevelDelta(
        scope=b.scope,
        back_before=old_back,
        back_after=b.back_wires,
        cycle_before=max([len(c) for c in a.cycles] + [0]),
        cycle_after=max([len(c) for c in b.cycles] + [0]),
        viol_before=a.violations,
        viol_after=b.violations,
        is_new=not a.nodes and bool(b.nodes),
        groups=len(b.nodes),
        wires=b.wires
    );
    if d.is_new {
        return d;
    }
    for e in b.back_edges() {
        old = a.edge_of(e.src, e.dst);
        if old is None {
            d.new_back.append((b.label_of(e.src), b.label_of(e.dst), e.count()));
        }
    }
    for e in a.edges.values() {
        if order_of(e.src) > order_of(e.dst) and b.edge_of(e.src, e.dst) is None {
            d.gone_back.append((a.label_of(e.src), a.label_of(e.dst), e.count()));
        }
    }
    def exported(lvl: GraphLevel) -> dict[str, int] {
        names: dict[str, set[str]] = {};
        for e in lvl.edges.values() {
            for w in e.wires {
                for n in wire_names(w) {
                    names.setdefault(lvl.label_of(e.src), set()).add(
                        f"{w.provider}.{n}"
                    );
                }
            }
        }
        return {g: len(v) for (g, v) in names.items()};
    }
    (ea, eb) = (exported(a), exported(b));
    for g in sorted(set(ea) | set(eb)) {
        if ea.get(g, 0) != eb.get(g, 0) {
            d.iface.append((g, ea.get(g, 0), eb.get(g, 0)));
        }
    }
    return d;
}

impl arch_diff(model: ProjectModel, rev: str) -> ArchDiff {
    t0 = time.time();
    base = review_base(model.root_dir, rev);
    d = ArchDiff(base=rev if base == rev else f"{rev} (merge-base {base[:10]})");
    (before, error, tmp) = model_at_rev(model, base);
    if before is None {
        d.error = error;
        return d;
    }
    try {
        def by_ends(m: ProjectModel) -> dict[tuple[str, str, str], list[WireInfo]] {
            out: dict[tuple[str, str, str], list[WireInfo]] = {};
            for w in m.wires {
                out.setdefault((w.provider, w.consumer, w.scope), []).append(w);
            }
            return out;
        }
        def same(a: WireInfo, b: WireInfo) -> bool {
            return a.form == b.form and sorted(a.names) == sorted(b.names);
        }
        old = by_ends(before);
        fresh = by_ends(model);
        for k in sorted(set(old) | set(fresh)) {
            olds = list(old.get(k, []));
            news: list[WireInfo] = [];
            for w in fresh.get(k, []) {
                hit = -1;
                for (i, o) in enumerate(olds) {
                    if same(o, w) {
                        hit = i;
                        break;
                    }
                }
                if hit >= 0 {
                    o = olds.pop(hit);
                    if w.violation and not o.violation {
                        d.new_violations.append(w);
                    }
                    if o.violation and not w.violation {
                        d.fixed_violations.append(w);
                    }
                } else {
                    news.append(w);
                }
            }
            for (o, w) in zip(olds, news) {
                (on, nn) = (set(o.names), set(w.names));
                if nn - on {
                    d.names_added.append((w, sorted(nn - on)));
                }
                if on - nn {
                    d.names_removed.append((w, sorted(on - nn)));
                }
                if o.form != w.form {
                    d.forms_changed.append((w, o.form, w.form));
                }
                if w.violation and not o.violation {
                    d.new_violations.append(w);
                }
                if o.violation and not w.violation {
                    d.fixed_violations.append(w);
                }
            }
            for w in news[len(olds):] {
                d.added.append(w);
                if w.violation {
                    d.new_violations.append(w);
                }
            }
            for o in olds[len(news):] {
                d.removed.append(o);
                if o.violation {
                    d.fixed_violations.append(o);
                }
            }
        }
        def rule_id(m: ProjectModel, r: StRule) -> tuple[str, str] {
            return (
                os.path.relpath(os.path.realpath(r.file), os.path.realpath(m.root_dir)),
                r.name
            );
        }
        def rule_sig(r: StRule) -> str {
            return " | ".join(r.sources)
                + " --> "
                + " | ".join(r.targets)
                + " {"
                + ",".join(r.names)
                + "}";
        }
        ro = {rule_id(before, r): r for r in before.rules};
        rn = {rule_id(model, r): r for r in model.rules};
        all_names = [k[1] for k in set(ro) | set(rn)];
        def label(k: tuple[str, str]) -> str {
            return k[1] if all_names.count(k[1]) == 1 else f"{k[1]} ({k[0]})";
        }
        d.rules_added = sorted(
            [
                label(k)
                for k in rn
                if k not in ro
            ]
        );
        d.rules_removed = sorted(
            [
                label(k)
                for k in ro
                if k not in rn
            ]
        );
        for k in sorted(rn) {
            if k not in ro or rule_sig(ro[k]) == rule_sig(rn[k]) {
                continue;
            }
            (prior, r) = (ro[k], rn[k]);
            bits: list[str] = [];
            for (what, x, y) in [
                ("source", prior.sources, r.sources),
                ("target", prior.targets, r.targets),
                ("name", prior.names, r.names)
            ] {
                for t in sorted(set(y) - set(x)) {
                    bits.append(f"+{what} {t}");
                }
                for t in sorted(set(x) - set(y)) {
                    bits.append(f"-{what} {t}");
                }
            }
            d.rules_changed.append(label(k));
            d.rule_changes[label(k)] = bits;
        }
        scopes = [effective_scope(model, "")];
        top = graph_level(model, scopes[0]);
        for nd in top.nodes {
            if nd.kind == "package" {
                scopes.append(nd.key);
                sub = graph_level(model, nd.key);
                for nd2 in sub.nodes {
                    if nd2.kind == "package" and len(scopes) < 80 {
                        scopes.append(nd2.key);
                    }
                }
            }
        }
        seen: set[str] = set();
        for sc in scopes {
            ld = level_delta(before, model, sc);
            if ld.scope in seen {
                continue;
            }
            seen.add(ld.scope);
            if ld.changed() and not (ld.is_new and ld.wires == 0) {
                d.levels.append(ld);
            }
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
    d.secs = time.time() - t0;
    return d;
}

impl diff_text(d: ArchDiff) -> str {
    if d.error {
        return f"jac hack diff: {d.error}";
    }
    lines = [
        f"Architecture changes since {d.base}: {len(d.added)} wire(s) added, {len(
            d.removed
        )} removed, "
            + f"{len(d.names_added)
                + len(d.names_removed)
                + len(d.forms_changed)} changed what they carry or how they load; "
            + f"{len(d.rules_added)} rule(s) added, {len(d.rules_removed)} removed, {len(
                d.rules_changed
            )} changed."
    ];
    if not (
        d.added
        or d.removed
        or d.names_added
        or d.names_removed
        or d.forms_changed
        or d.rules_added
        or d.rules_removed
        or d.rules_changed
    ) {
        lines.append("The wiring is the same.");
        return "\n".join(lines);
    }
    if d.new_violations {
        lines.append("");
        lines.append(f"New rule violations ({len(d.new_violations)}):");
        for w in d.new_violations[:10] {
            lines.append(f"  {w.provider} ++> {w.consumer}: {w.violation}");
        }
    }
    if d.fixed_violations {
        lines.append(f"Violations fixed: {len(d.fixed_violations)}");
    }
    for ld in d.levels {
        if ld.is_new {
            lines.append("");
            lines.append(
                f"{ld.scope} is new: {ld.groups} groups, {ld.wires} wires between them, {ld.back_after} backward"
                    + (
                        f", largest cycle {ld.cycle_after} groups"
                            if ld.cycle_after
                            else ""
                    )
            );
            continue;
        }
        bits: list[str] = [];
        if ld.back_before != ld.back_after {
            bits.append(f"backward wires {ld.back_before} -> {ld.back_after}");
        }
        if ld.cycle_before != ld.cycle_after {
            bits.append(f"largest cycle {ld.cycle_before} -> {ld.cycle_after} groups");
        }
        if ld.viol_before != ld.viol_after {
            bits.append(f"violations {ld.viol_before} -> {ld.viol_after}");
        }
        lines.append("");
        lines.append(
            f"In {ld.scope or 'the project'}: "
                + ("; ".join(bits) if bits else "same layering")
        );
        for (a, b, n) in ld.new_back[:8] {
            lines.append(f"  new backward dependency: {a} -> {b} ({n} wire(s))");
        }
        for (a, b, n) in ld.gone_back[:8] {
            lines.append(f"  backward dependency gone: {a} -> {b}");
        }
        for (g, x, y) in ld.iface[:10] {
            lines.append(f"  {g} exports {x} -> {y} name(s)");
        }
    }
    if d.added {
        lines.append("");
        lines.append("Wires added:");
        for w in d.added[:25] {
            lines.append(
                f"  + {w.provider} ++> {w.consumer} {{ {', '.join(w.names)
                    if w.names
                    else WHOLE} }}"
            );
        }
        if len(d.added) > 25 {
            lines.append(f"  ... and {len(d.added) - 25} more");
        }
    }
    if d.removed {
        lines.append("Wires removed:");
        for w in d.removed[:25] {
            lines.append(f"  - {w.provider} ++> {w.consumer}");
        }
        if len(d.removed) > 25 {
            lines.append(f"  ... and {len(d.removed) - 25} more");
        }
    }
    for (w, ns) in d.names_added[:15] {
        lines.append(
            f"  {w.provider} ++> {w.consumer} now also carries {', '.join(ns)}"
        );
    }
    for (w, ns) in d.names_removed[:15] {
        lines.append(
            f"  {w.provider} ++> {w.consumer} no longer carries {', '.join(ns)}"
        );
    }
    for (w, was, now) in d.forms_changed[:15] {
        lines.append(
            f"  {w.provider} ++> {w.consumer} now loads as '{now}' (was '{was}')"
        );
    }
    for n in d.rules_added {
        lines.append(f"Rule added: {n}");
    }
    for n in d.rules_removed {
        lines.append(f"Rule removed: {n}");
    }
    for n in d.rules_changed {
        lines.append(f"Rule changed: {n}  " + ", ".join(d.rule_changes.get(n, [])));
    }
    lines.append("");
    lines.append(f"({d.secs:.1f}s)");
    return "\n".join(lines);
}

impl diff_dict(d: ArchDiff) -> dict[str, any] {
    return {
        "base": d.base,
        "error": d.error,
        "added": [w.to_dict() for w in d.added],
        "removed": [w.to_dict() for w in d.removed],
        "names_added": [
            {"wire": w.to_dict(), "names": ns} for (w, ns) in d.names_added
        ],
        "names_removed": [
            {"wire": w.to_dict(), "names": ns} for (w, ns) in d.names_removed
        ],
        "forms_changed": [
            {"wire": w.to_dict(), "was": a, "now": b} for (w, a, b) in d.forms_changed
        ],
        "rules_added": d.rules_added,
        "rules_removed": d.rules_removed,
        "rules_changed": d.rule_changes,
        "new_violations": [w.to_dict() for w in d.new_violations],
        "fixed_violations": len(d.fixed_violations),
        "levels": [
            {
                "scope": ld.scope,
                "backward_before": ld.back_before,
                "backward_after": ld.back_after,
                "largest_cycle_before": ld.cycle_before,
                "largest_cycle_after": ld.cycle_after,
                "violations_before": ld.viol_before,
                "violations_after": ld.viol_after,
                "new_backward": [
                    {"from": a, "to": b, "wires": n} for (a, b, n) in ld.new_back
                ],
                "gone_backward": [
                    {"from": a, "to": b, "wires": n} for (a, b, n) in ld.gone_back
                ],
                "exports": [
                    {"group": g, "before": x, "after": y} for (g, x, y) in ld.iface
                ]
            } for ld in d.levels
        ]
    };
}

impl default_base(where: str) -> str {
    def git(args: list[str]) -> str {
        return subprocess.run(
            ["git", "-C", where] + args, capture_output=True, text=True, check=True
        ).stdout.strip();
    }
    try {
        refs = git(
            [
                "for-each-ref",
                "--format=%(refname:short)",
                "refs/heads/main",
                "refs/heads/master",
                "refs/remotes/*/main",
                "refs/remotes/*/master"
            ]
        ).split();
    } except Exception {
        return "HEAD~1";
    }
    best = "";
    best_ahead = -1;
    for ref in refs {
        try {
            base = git(["merge-base", ref, "HEAD"]);
            ahead = int(git(["rev-list", "--count", f"{base}..HEAD"]));
        } except Exception {
            continue;
        }
        if best_ahead < 0 or ahead < best_ahead {
            (best, best_ahead) = (ref, ahead);
        }
    }
    return best or "HEAD~1";
}

impl insight_run(model: ProjectModel, view: str, key: str, as_text: bool) -> any {
    if view == "roles" {
        rr = module_roles(model, key);
        return roles_text(rr) if as_text else roles_dict(rr);
    }
    if view == "interface" {
        ir = interface_of(model, key);
        return interface_text(ir) if as_text else interface_dict(ir);
    }
    if view == "rules" {
        ar = intent_report(model);
        return intent_text(ar, model) if as_text else intent_dict(ar);
    }
    if view in ["slice", "blast"] {
        rc = reach(model, key, "up" if view == "slice" else "down");
        return reach_text(rc, model) if as_text else reach_dict(rc);
    }
    if view == "clusters" {
        cr = cluster_report(model, key);
        return clusters_text(cr) if as_text else clusters_dict(cr);
    }
    if view == "tour" {
        text = tour_text(model, key);
        return text if as_text else {"markdown": text};
    }
    if view == "diff" {
        d = arch_diff(model, key or default_base(model.root_dir));
        return diff_text(d) if as_text else diff_dict(d);
    }
    raise ValueError(
        f"unknown view '{view}': roles, interface, rules, slice, blast, clusters, tour or diff"
    );
}

impl spec_parts(spec: str) -> dict[str, str] {
    parts: dict[str, str] = {};
    for p in spec.split("&") {
        if not p {
            continue;
        }
        (k, _, v) = p.partition("=");
        parts[k] = v;
    }
    return parts;
}

impl filter_modules(model: ProjectModel, spec: str) -> (set[str] | None) {
    if not spec {
        return None;
    }
    parts = spec_parts(spec);
    if "slice" in parts or "blast" in parts {
        up = "slice" in parts;
        r = reach(
            model,
            parts.get("slice", "") if up else parts.get("blast", ""),
            "up" if up else "down"
        );
        if not r.seeds {
            return set();
        }
        if "all" in parts {
            return r.modules();
        }
        mods: set[str] = set(r.seeds);
        for step in r.eager_steps {
            mods.update(step);
        }
        return mods if len(mods) > len(r.seeds) else r.modules();
    }
    if "cluster" in parts {
        (cid, _, cscope) = parts["cluster"].partition("@");
        for cl in cluster_report(model, cscope).clusters {
            if str(cl.id) == cid {
                return set(cl.members);
            }
        }
        return set();
    }
    return None;
}

impl filter_label(spec: str) -> str {
    parts = spec_parts(spec);
    when = "through any wire" if "all" in parts else "at import time";
    if "slice" in parts {
        return f"slice of {parts['slice']} ({when})";
    }
    if "blast" in parts {
        return f"blast radius of {parts['blast']} ({when})";
    }
    if "cluster" in parts {
        (cid, _, cscope) = parts["cluster"].partition("@");
        return f"cluster #{cid} of {cscope or 'the project'}";
    }
    return spec;
}
