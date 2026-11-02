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
