import os;
import sys;
import json;
import queue;
import shutil;
import difflib;
import time;

glob ACTIONS: list[str] = [
         "model",
         "graph",
         "roles",
         "interface",
         "rules",
         "slice",
         "blast",
         "clusters",
         "tour",
         "diff",
         "ask",
         "agents",
         "sessions",
         "mcp"
     ],
     INSIGHT_ACTIONS: list[str] = [
         "roles",
         "interface",
         "rules",
         "slice",
         "blast",
         "clusters",
         "tour",
         "diff"
     ];

def out(text: str);

def err(text: str);

def run_studio(
    action: str,
    args: list[str],
    agent: str,
    session: str,
    as_json: bool,
    directory: str
) -> int;

def cmd_model(root_dir: str, args: list[str], as_json: bool) -> int;

def cmd_graph(root_dir: str, args: list[str], as_json: bool) -> int;

def cmd_insight(root_dir: str, action: str, args: list[str], as_json: bool) -> int;

def resolve_scope_arg(model: ProjectModel, target: str) -> (str | None);

def cmd_gate(directory: str, args: list[str], as_json: bool) -> int;
def cmd_mcp(root_dir: str, args: list[str]) -> int;

def format_summary(model: ProjectModel) -> str;

def cmd_intel(directory: str, args: list[str]) -> int;

def paint_line(text: str, spans: list[Span]) -> str;

def wait_ready(ci: CodeIntel, path: str, timeout: float = 600.0) -> str;

def wait_tickets(
    ci: CodeIntel, tickets: list[int], timeout: float = 120.0
) -> dict[int, any];

def cmd_agents(root_dir: str, as_json: bool) -> int;

def cmd_sessions(root_dir: str, as_json: bool, args: list[str]) -> int;

def cmd_ask(
    root_dir: str,
    args: list[str],
    agent: str,
    session_id: str,
    assume_yes: bool,
    as_json: bool
) -> int;

def build_model(root_dir: str) -> ProjectModel;

obj AskView {
    has root_dir: str,
        in_text: bool = False,
        titles: dict[str, str] = {},
        kinds: dict[str, str] = {},
        order: list[str] = [],
        calls: dict[str, dict[str, any]] = {},
        shown: list[str] = [];

    def chunk(text: str) -> None;
    def line(text: str) -> None;
    def tool(d: dict[str, any]) -> None;
    def show_tool(tid: str, failed: bool) -> None;
    def flush_tools -> None;
}


def choose_permission(
    data: dict[str, any],
    assume_yes: bool,
    root_dir: str,
    known: (dict[str, any] | None) = None
) -> (str | None);

def format_module(model: ProjectModel, key: str) -> str;

def format_symbol(model: ProjectModel, key: str) -> str;

impl out(text: str) {
    sys.stdout.write(text + "\n");
    sys.stdout.flush();
}

impl err(text: str) {
    sys.stderr.write(text + "\n");
    sys.stderr.flush();
}

impl run_studio(
    action: str,
    args: list[str],
    agent: str,
    session: str,
    as_json: bool,
    directory: str
) -> int {
    rest: list[str] = [];
    assume_yes = False;
    i = 0;
    while i < len(args) {
        a = args[i];
        nxt = args[i + 1] if i + 1 < len(args) else "";
        if a in ["-a", "--agent"] and nxt {
            agent = nxt;
            i += 2;
        } elif a in ["-s", "--session"] and nxt {
            session = nxt;
            i += 2;
        } elif a in ["-d", "--dir"] and nxt {
            directory = nxt;
            i += 2;
        } elif a == "--json" {
            as_json = True;
            i += 1;
        } elif a in ["-y", "--yes"] {
            assume_yes = True;
            i += 1;
        } elif a.startswith("--agent=") {
            agent = a.split("=", 1)[1];
            i += 1;
        } elif a.startswith("--session=") {
            session = a.split("=", 1)[1];
            i += 1;
        } elif a.startswith("--dir=") {
            directory = a.split("=", 1)[1];
            i += 1;
        } else {
            rest.append(a);
            i += 1;
        }
    }
    args = rest;
    if action == "intel" {
        return cmd_intel(directory, args);
    }
    if action == "gate" {
        return cmd_gate(directory, args, as_json);
    }
    root_dir = find_project_root(directory or os.getcwd());
    try {
        cfg = get_config_for_dir(root_dir);
        if cfg is not None {
            add_venv_to_path(cfg);
        }
    } except Exception {}
    if action == "model" {
        return cmd_model(root_dir, args, as_json);
    }
    if action == "graph" {
        return cmd_graph(root_dir, args, as_json);
    }
    if action in INSIGHT_ACTIONS {
        return cmd_insight(root_dir, action, args, as_json);
    }
    if action == "agents" {
        return cmd_agents(root_dir, as_json);
    }
    if action == "sessions" {
        return cmd_sessions(root_dir, as_json, args);
    }
    if action == "ask" {
        return cmd_ask(root_dir, args, agent, session, assume_yes, as_json);
    }
    if action == "mcp" {
        return cmd_mcp(root_dir, args);
    }
    if action == "" {
        return run_tui(root_dir, agent, session);
    }
    err(
        f"jac studio: unknown action '{action}'. Expected one of: " + ", ".join(ACTIONS)
    );
    return 2;
}

impl cmd_model(root_dir: str, args: list[str], as_json: bool) -> int {
    model = ProjectModel(root_dir=root_dir);
    show = sys.stderr.isatty();
    def progress(n: int, total: int, key: str) {
        if show and (n % 25 == 0 or n == total) {
            sys.stderr.write(f"\r  indexing {n}/{total} modules");
            sys.stderr.flush();
        }
    }
    model.build(on_progress=progress);
    if show {
        sys.stderr.write("\r" + " " * 40 + "\r");
    }
    target = args[0] if args else "";
    if target and target not in model.modules and target in model.symbols {
        if as_json {
            nd = model.symbols[target];
            found = model.node_dict(nd);
            found["users"] = [u.key for u in model.users_of(target)];
            found["uses"] = [u.key for u in model.uses_of(target)];
            found["implementations"] = [i.file for i in model.implementations(target)];
            found["walkers"] = [w.key for w in model.walkers_of(target)];
            out(json.dumps(found, indent=2));
        } else {
            out(format_symbol(model, target));
        }
        return 0;
    }
    if target and target not in model.modules {
        hits = model.search(target, limit=1, kinds=["module"]);
        if hits {
            target = hits[0].key;
        }
    }
    if target and target not in model.modules {
        err(f"jac studio model: no module or symbol matches '{args[0]}'");
        return 1;
    }
    if as_json {
        out(json.dumps(model.to_dict(target), indent=2));
        return 0;
    }
    if target {
        if target not in model.modules {
            err(f"jac studio model: no module matches '{args[0]}'");
            return 1;
        }
        out(format_module(model, target));
        return 0;
    }
    out(format_summary(model));
    return 0;
}

impl resolve_scope_arg(model: ProjectModel, target: str) -> (str | None) {
    if not target {
        return "";
    }
    for k in model.modules.keys() {
        if in_scope(k, target) or target.startswith(k + ".") {
            return target;
        }
    }
    hits = model.search(target, limit=1, kinds=["module"]);
    if hits and target.lower().split(".")[-1] in hits[0].key.lower() {
        return hits[0].key;
    }
    return None;
}

impl cmd_insight(root_dir: str, action: str, args: list[str], as_json: bool) -> int {
    model = ProjectModel(root_dir=root_dir);
    model.build(index=action == "tour");
    target = args[0] if args else "";
    if action == "diff" {
        d = arch_diff(model, target or default_base(root_dir));
        out(json.dumps(diff_dict(d), indent=2) if as_json else diff_text(d));
        return 1 if d.error else 0;
    }
    key = resolve_scope_arg(model, target);
    if key is None {
        err(f"jac studio {action}: no package or module matches '{target}'");
        return 1;
    }
    if action in ["interface", "slice", "blast"] and not key {
        err(f"jac studio {action}: name a package, module or symbol");
        return 2;
    }
    if action == "roles" {
        roles = module_roles(model, key);
        out(json.dumps(roles_dict(roles), indent=2) if as_json else roles_text(roles));
    } elif action == "interface" {
        iface = interface_of(model, key);
        out(
            json.dumps(interface_dict(iface), indent=2)
                if as_json
                else interface_text(iface)
        );
    } elif action == "rules" {
        intent = intent_report(model);
        out(
            json.dumps(intent_dict(intent), indent=2)
                if as_json
                else intent_text(intent, model)
        );
    } elif action in ["slice", "blast"] {
        depth = int(args[1]) if len(args) > 1 and args[1].isdigit() else 0;
        found = reach(model, key, "up" if action == "slice" else "down", depth);
        out(
            json.dumps(reach_dict(found), indent=2)
                if as_json
                else reach_text(found, model)
        );
    } elif action == "clusters" {
        cl = cluster_report(model, key);
        out(json.dumps(clusters_dict(cl), indent=2) if as_json else clusters_text(cl));
    } elif action == "tour" {
        out(tour_text(model, key));
    }
    return 0;
}

impl cmd_graph(root_dir: str, args: list[str], as_json: bool) -> int {
    model = ProjectModel(root_dir=root_dir);
    model.build(index=False);
    target = resolve_scope_arg(model, args[0] if args else "");
    if target is None {
        err(f"jac studio graph: no package or module matches '{args[0]}'");
        return 1;
    }
    level = graph_level(model, scope_for(model, target));
    if as_json {
        out(json.dumps(level_dict(level, model), indent=2));
    } else {
        out(level_text(level, model));
    }
    return 0;
}

impl cmd_gate(directory: str, args: list[str], as_json: bool) -> int {
    repeat = 1;
    files: list[str] = [];
    i = 0;
    while i < len(args) {
        if args[i] == "--repeat" and i + 1 < len(args) {
            repeat = max(1, int(args[i + 1]));
            i += 2;
            continue;
        }
        files.append(args[i]);
        i += 1;
    }
    if len(files) != 2 {
        err("usage: jac studio gate <file> <new-file> [--repeat N] [-d DIR] [--json]");
        return 2;
    }
    target = os.path.abspath(files[0]);
    if not os.path.isfile(files[1]) {
        err(f"jac studio gate: no such file '{files[1]}'");
        return 2;
    }
    with open(files[1], encoding="utf-8") as fh {
        new_text = fh.read();
    }
    root_dir = find_project_root(directory or os.path.dirname(target));
    gate = EditGate(root_dir=root_dir);
    reviews: list[EditReview] = [];
    for _ in range(repeat) {
        reviews.append(gate.review(target, new_text));
    }
    rv = reviews[-1];
    if as_json {
        data = rv.to_dict();
        data["timings"] = [round(r.elapsed, 3) for r in reviews];
        data["feedback"] = rv.feedback();
        out(json.dumps(data, indent=2));
    } else {
        out(format_review(rv));
        if repeat > 1 {
            out("\ntimings: " + ", ".join([f"{r.elapsed:.2f}s" for r in reviews]));
        }
    }
    return 0 if rv.clean() else 1;
}

impl cmd_mcp(root_dir: str, args: list[str]) -> int {
    sock = "";
    i = 0;
    while i < len(args) {
        a = args[i];
        if a == "--socket" and i + 1 < len(args) {
            sock = args[i + 1];
            i += 2;
        } elif a.startswith("--socket=") {
            sock = a.split("=", 1)[1];
            i += 1;
        } else {
            err(
                f"jac studio mcp: unexpected argument '{a}' (usage: jac studio mcp [--socket PATH])"
            );
            return 2;
        }
    }
    return serve_studio_mcp(sock, root_dir);
}

impl format_summary(model: ProjectModel) -> str {
    st = model.stats();
    lines = [
        f"{model.root_dir}",
        f"  {st['modules']} modules in {st['packages']} packages, {st[
            'external'
        ]} external providers",
        f"  {st['wires']} wires, {st['rules']} rules, {len(
            model.archwires
        )} archwire.jac files",
        "  symbols: "
            + ", ".join([f"{v} {k}" for (k, v) in sorted(st["symbols"].items())]),
        f"  discovered in {st['discover_secs']}s, indexed in {st['index_secs']}s"
    ];
    if st["errors"] {
        lines.append(f"  {st['errors']} modules failed to parse");
    }
    tops = [
        k
        for k in model.packages
        if "." not in k
    ];
    if tops {
        lines.append("  top-level packages: " + ", ".join(sorted(tops)));
    }
    return "\n".join(lines);
}

impl format_module(model: ProjectModel, key: str) -> str {
    mod = model.modules[key];
    lines = [f"{key}  ({mod.file})"];
    rules = model.rules_for(key);
    if rules {
        lines.append("  governed by: " + ", ".join([r.name for r in rules]));
    }
    provs = model.providers(key);
    if provs {
        lines.append("  feeds this:");
        for w in provs {
            scope = f" -> {w.scope}" if w.scope else "";
            names = ", ".join(w.names) if w.names else "(module)";
            lines.append(f"    {w.provider}{scope}  {{ {names} }}");
        }
    }
    cons = model.consumers(key);
    if cons {
        lines.append("  consumed by:");
        for w in cons {
            names = ", ".join(w.names) if w.names else "(module)";
            lines.append(f"    {w.consumer}  {{ {names} }}");
        }
    }
    lines.append("  symbols:");
    def walk(nd: any, depth: int) {
        sig = getattr(nd, "signature", "") or getattr(nd, "type_str", "");
        loc = f"{os.path.basename(nd.file)}:{nd.line}" if nd.file else "";
        idef = "";
        if getattr(nd, "impl_file", "") {
            idef = f"  impl {os.path.basename(nd.impl_file)}:{nd.impl_line}";
        }
        lines.append(
            "    "
                + "  " * depth
                + f"{nd.kind} {nd.name} {sig}".rstrip()
                + f"  [{loc}]{idef}"
        );
        for kid in model.children(nd.key) {
            walk(kid, depth + 1);
        }
    }
    for kid in model.children(key) {
        walk(kid, 0);
    }
    return "\n".join(lines);
}

glob STYLE_COLORS: dict[str, int] = {
         "keyword": 170,
         "builtin": 168,
         "builtin_type": 38,
         "constant": 208,
         "number": 179,
         "string": 114,
         "docstring": 108,
         "comment": 244,
         "operator": 110,
         "punct": 248,
         "name": 252,
         "function": 75,
         "method": 81,
         "macro": 75,
         "class": 221,
         "struct": 221,
         "interface": 221,
         "type": 38,
         "type_parameter": 38,
         "enum": 215,
         "enum_member": 215,
         "namespace": 147,
         "parameter": 216,
         "variable": 252,
         "property": 117,
         "event": 117,
         "decorator": 180,
         "embedded": 139,
         "tag": 167,
         "text": 252,
         "error": 196
     };

impl paint_line(text: str, spans: list[Span]) -> str {
    out: list[str] = [];
    cursor = 0;
    for sp in spans {
        if sp.start < cursor or sp.start >= len(text) {
            continue;
        }
        if sp.start > cursor {
            out.append(text[cursor:sp.start]);
        }
        parts = sp.style.split(".");
        color = STYLE_COLORS.get(parts[0], 252);
        bold = "1;" if "declaration" in parts or "definition" in parts else "";
        italic = "3;" if parts[0] in ["comment", "docstring"] else "";
        out.append(
            f"\x1b[{bold}{italic}38;5;{color}m" + text[sp.start:sp.end] + "\x1b[0m"
        );
        cursor = min(sp.end, len(text));
    }
    out.append(text[cursor:]);
    return "".join(out);
}

impl wait_ready(ci: CodeIntel, path: str, timeout: float = 600.0) -> str {
    deadline = time.time() + timeout;
    st = ci.status(path);
    while time.time() < deadline {
        st = ci.status(path);
        if st == "ready" or st.startswith("error") {
            return st;
        }
        time.sleep(0.02);
    }
    return st;
}

impl wait_tickets(
    ci: CodeIntel, tickets: list[int], timeout: float = 120.0
) -> dict[int, any] {
    got: dict[int, any] = {};
    deadline = time.time() + timeout;
    while len(got) < len(tickets) and time.time() < deadline {
        for (t, res) in ci.poll() {
            got[t] = res;
        }
        if len(got) < len(tickets) {
            time.sleep(0.02);
        }
    }
    return got;
}

impl cmd_intel(directory: str, args: list[str]) -> int {
    max_apps = 1;
    if "--apps" in args {
        at = args.index("--apps");
        max_apps = int(args[at + 1]) if at + 1 < len(args) else 1;
        args = args[:at] + args[at + 2:];
    }
    if not args {
        err(
            "usage: jac studio intel <file.jac> [line col] [--apps N]   (line and col are 1-based)"
        );
        return 2;
    }
    path = os.path.realpath(args[0]);
    if not os.path.isfile(path) {
        err(f"jac studio intel: no such file: {args[0]}");
        return 1;
    }
    line = int(args[1]) if len(args) > 1 else 0;
    col = int(args[2]) - 1 if len(args) > 2 else 0;
    root_dir = find_project_root(directory or os.path.dirname(path));
    ci = CodeIntel(max_apps=max_apps);
    t0 = time.perf_counter();
    lexed = ci.highlight(path);
    hl_secs = time.perf_counter() - t0;
    t0 = time.perf_counter();
    ci.highlight(path);
    hl_cached = time.perf_counter() - t0;
    t_start = time.perf_counter();
    ci.start(root_dir);
    try {
        ci.request_check(path);
        with open(path, "r", encoding="utf-8", errors="replace") as f {
            edited = f.read() + "\n";
        }
        time.sleep(0.3);
        t0 = time.perf_counter();
        ci.highlight(path, edited);
        hl_busy = time.perf_counter() - t0;
        st = wait_ready(ci, path);
        first_sem = time.perf_counter() - t_start;
        check_cold = ci.check_secs(path);
        styles = ci.line_styles(path);
        with open(path, "r", encoding="utf-8", errors="replace") as f {
            lines = f.read().split("\n");
        }
        lo = max(0, line - 20) if line else 0;
        hi = min(len(lines), lo + 40);
        out(f"== {path}  [{st}]  lines {lo + 1}-{hi} of {len(lines)}");
        for i in range(lo, hi) {
            mark = ">" if i + 1 == line else " ";
            out(
                f"{mark}{i + 1:5d} "
                    + paint_line(lines[i], styles[i] if i < len(styles) else [])
            );
        }
        sem_rows = ci.semantic(path);
        nsem = sum([len(r) for r in sem_rows]) if sem_rows else 0;
        diags = ci.diagnostics(path);
        out(f"== diagnostics ({len(diags)})");
        for d in diags {
            out(
                f"  {d.severity} {d.code} {d.line}:{d.col + 1}-{d.end_line}:{d.end_col
                    + 1}  {d.message}"
            );
            if d.help {
                out(f"      help: {d.help.splitlines()[0]}");
            }
        }
        if line {
            snippet = lines[line - 1] if 0 < line <= len(lines) else "";
            out(f"== position {line}:{col + 1}  {snippet.strip()}");
            out(f"  symbol_at: {ci.symbol_at(path, line, col)}");
            th = ci.request_hover(path, line, col);
            td = ci.request_definition(path, line, col);
            tr = ci.request_references(path, line, col);
            got = wait_tickets(ci, [th, td, tr]);
            hover = got.get(th);
            out("  hover:");
            for hl in (str(hover) if hover else "(none)").splitlines() {
                out(f"    {hl}");
            }
            out(f"  definition: {got.get(td)}");
            refs = got.get(tr) or [];
            out(f"  references ({len(refs)}):");
            for r in refs[:30] {
                out(
                    f"    {os.path.relpath(r['path'], root_dir)}:{r['line']}:{r['col']
                        + 1}  {r.get('text', '')}"
                );
            }
        }
        ci.invalidate(path);
        wait_ready(ci, path);
        check_warm = ci.check_secs(path);
        out(
            f"== timings: highlight {hl_secs * 1000:.1f} ms for {len(
                lexed
            )} lines (cached {hl_cached * 1000:.2f} ms, while the worker compiles {hl_busy
                * 1000:.1f} ms), "
                + f"first semantic tokens {first_sem:.2f} s (cold check {check_cold:.2f} s), "
                + f"warm re-check {check_warm:.2f} s, {nsem} semantic tokens"
        );
        out(f"== log: {ci.log_path}");
    } finally {
        ci.stop();
    }
    return 0;
}

impl cmd_agents(root_dir: str, as_json: bool) -> int {
    reg = AgentRegistry(root_dir=root_dir);
    rows = reg.describe();
    if as_json {
        out(json.dumps({"default": reg.default_name(), "agents": rows}, indent=2));
        return 0;
    }
    width = max([len(r["name"]) for r in rows] + [4]);
    for r in rows {
        mark = "*" if r["default"] else " ";
        state = "ready" if r["runnable"] else "unavailable";
        if r["kind"] == "builtin" {
            what = f"built-in byllm agent (model: {r.get('model', '')})";
        } else {
            what = " ".join([r["command"], *r["args"]]);
        }
        line = f"{mark} {r['name'].ljust(width)}  {state.ljust(11)}  {what}";
        if not r["runnable"] and r["reason"] {
            line += f"  ({r['reason']})";
        }
        if r["source"] != "builtin" {
            line += f"  [{r['source']} config]";
        }
        out(line);
    }
    out(f"default: {reg.default_name()}  (set [studio] default_agent in jac.toml)");
    return 0;
}

impl cmd_sessions(root_dir: str, as_json: bool, args: list[str]) -> int {
    if args and args[0] == "fork" {
        if len(args) < 2 {
            err("usage: jac studio sessions fork <session-id>");
            return 1;
        }
        child = fork_session(root_dir, args[1]);
        if child is None {
            err(f"jac studio sessions: no saved session matches '{args[1]}'");
            return 1;
        }
        out(
            json.dumps(child.summary())
                if as_json
                else f"forked {child.parent} as {child.id}; resume it with: jac studio -s {child.id}"
        );
        return 0;
    }
    rows = list_sessions(root_dir);
    if as_json {
        out(json.dumps(rows, indent=2));
        return 0;
    }
    if not rows {
        out(f"no saved sessions under {sessions_dir(root_dir)}");
        return 0;
    }
    for r in rows {
        when = time.strftime("%Y-%m-%d %H:%M", time.localtime(float(r["updated"])));
        fork = f"  (fork of {r['parent']})" if r.get("parent") else "";
        out(
            f"{r['id']}  {when}  {r['agent'] or '?':8}  {r['entries']:3} entries  {r[
                'title'
            ]}{fork}"
        );
    }
    return 0;
}

impl build_model(root_dir: str) -> ProjectModel {
    model = ProjectModel(root_dir=root_dir);
    show = sys.stderr.isatty();
    def progress(n: int, total: int, key: str) {
        if show and (n % 25 == 0 or n == total) {
            sys.stderr.write(f"\r  indexing {n}/{total} modules");
            sys.stderr.flush();
        }
    }
    model.build(on_progress=progress);
    if show {
        sys.stderr.write("\r" + " " * 40 + "\r");
    }
    return model;
}


impl choose_permission(
    data: dict[str, any],
    assume_yes: bool,
    root_dir: str,
    known: (dict[str, any] | None) = None
) -> (str | None) {
    tc = data.get("tool_call") or {};
    options = data.get("options") or [];
    title = tc.get("title") or tc.get("toolCallId") or "a tool call";
    out(f"\n  ? permission requested: {title}");
    for d in permission_diffs(tc, root_dir, known) {
        sys.stdout.write(d);
    }
    def first_of(kinds: list[str]) -> (str | None) {
        for k in kinds {
            for o in options {
                if o.get("kind") == k {
                    return o.get("optionId");
                }
            }
        }
        return None;
    }
    if assume_yes {
        pick = first_of(["allow_once", "allow_always"]);
        out(f"  -> allowed (--yes)");
        return pick;
    }
    if sys.stdin.isatty() {
        for (i, o) in enumerate(options) {
            out(f"    {i + 1}. {o.get('name', o.get('optionId'))}");
        }
        sys.stdout.write("    choose a number (enter to reject): ");
        sys.stdout.flush();
        try {
            ans = sys.stdin.readline().strip();
        } except (OSError, KeyboardInterrupt) {
            ans = "";
        }
        if ans.isdigit() and 1 <= int(ans) <= len(options) {
            return options[int(ans) - 1].get("optionId");
        }
    } else {
        out("  -> rejected (stdin is not a terminal; pass --yes to allow)");
    }
    return first_of(["reject_once", "reject_always"]);
}

impl cmd_ask(
    root_dir: str,
    args: list[str],
    agent: str,
    session_id: str,
    assume_yes: bool,
    as_json: bool
) -> int {
    if len(args) < 2 {
        err(
            "usage: jac studio ask <symbol-or-module> \"<instruction>\" [--agent NAME] [--session ID] [--yes]"
        );
        return 2;
    }
    target = args[0];
    instruction = " ".join(args[1:]).strip();
    reg = AgentRegistry(root_dir=root_dir);
    st: (StudioSession | None) = None;
    if session_id {
        st = load_session(root_dir, session_id);
        if st is None {
            err(
                f"jac studio ask: no saved session '{session_id}' (see `jac studio sessions`)"
            );
            return 1;
        }
    }
    name = agent
        or (st.agent if st is not None and st.agent else "")
        or reg.default_name();
    spec = reg.get(name);
    if spec is None {
        err(f"jac studio ask: unknown agent '{name}'. Known: {', '.join(reg.names())}");
        return 1;
    }
    if not spec.runnable() {
        err(f"jac studio ask: agent '{name}' cannot run: {spec.reason()}");
        return 1;
    }
    model = build_model(root_dir);
    key = resolve_key(model, target);
    if not key {
        err(f"jac studio ask: nothing in the project model matches '{target}'");
        return 1;
    }
    if key != target {
        err(f"  using {key}");
    }
    if st is None {
        st = new_session(root_dir, agent=name);
    }
    resume_id = st.agent_session_id if st.agent == name else "";
    st.agent = name;
    if key not in st.tray {
        st.tray.append(key);
    }
    st.add("user", f"[{key}] {instruction}");
    def gate(path: str, content: str) -> (str | None) {
        old = "";
        try {
            with open(path, encoding="utf-8", errors="replace") as f {
                old = f.read();
            }
        } except OSError {}
        out(f"\n  ~ write requested: {os.path.relpath(path, root_dir)}");
        sys.stdout.write(unified_diff(path, old, content, root_dir));
        if assume_yes {
            out("  -> applied (--yes)");
            st.decide("write", True, path=path);
            return None;
        }
        out("  -> not applied (rerun with --yes to apply)");
        st.decide("write", False, path=path, message="needs --yes");
        return (
            "The user did not approve this write: `jac studio ask` applies edits only "
            + "with --yes. The proposed change was shown to the user as a diff; do not retry it."
        );
    }
    try {
        sess = reg.create_session(
            name, project_model=model, load_session_id=resume_id, write_gate=gate
        );
    } except Exception as e {
        err(f"jac studio ask: {e}");
        return 1;
    }
    err(f"  starting {name} ...");
    try {
        sess.start(root_dir, [jac_mcp_server()]);
    } except Exception as e {
        err(f"jac studio ask: could not start agent '{name}': {e}");
        sess.stop();
        return 1;
    }
    blocks = context_blocks(model, [key]) + [{"type": "text", "text": instruction}];
    rc = 0;
    view = AskView(root_dir=root_dir);
    try {
        sess.prompt(blocks);
        while True {
            try {
                ev = sess.events.get(timeout=0.5);
            } except queue.Empty {
                continue;
            }
            d = ev.data;
            if d.get("replay") {
                continue;
            }
            st.record(ev);
            if ev.kind == "message_chunk" {
                view.chunk(str(d.get("text", "")));
            } elif ev.kind in ["tool_call", "tool_call_update"] {
                view.tool(d);
            } elif ev.kind == "plan" {
                view.line("  plan:");
                for p in (d.get("entries") or []) {
                    view.line(f"    [{p.get('status', '')}] {p.get('content', '')}");
                }
            } elif ev.kind == "terminal" {
                if d.get("exit_code") is not None or d.get("signal") {
                    view.line(
                        f"  $ {d.get('command', '')}  (exit {d.get('exit_code')})"
                    );
                }
            } elif ev.kind == "permission" {
                view.line("");
                tcid = str((d.get("tool_call") or {}).get("toolCallId", ""));
                choice = choose_permission(
                    d, assume_yes, root_dir, view.calls.get(tcid)
                );
                st.decide(
                    "permission",
                    choice is not None and "reject" not in str(choice),
                    message=str(choice),
                    detail=str((d.get("tool_call") or {}).get("title", ""))
                );
                sess.respond_permission(d.get("request_id"), choice);
            } elif ev.kind == "write" {
                verdict = gate(str(d.get("path", "")), str(d.get("content", "")));
                sess.resolve_write(d.get("request_id"), verdict is None, verdict or "");
            } elif ev.kind == "error" {
                view.line("");
                err(f"error: {d.get('message', '')}");
                rc = 1;
            } elif ev.kind == "turn_end" {
                view.flush_tools();
                view.line("");
                reason = str(d.get("stop_reason", ""));
                if reason != "end_turn" {
                    err(f"(turn ended: {reason})");
                    if reason == "error" {
                        rc = 1;
                    }
                }
                break;
            }
        }
    } except KeyboardInterrupt {
        err("\ncancelling ...");
        sess.cancel();
        deadline = time.time() + 20;
        while time.time() < deadline {
            try {
                ev = sess.events.get(timeout=0.5);
            } except queue.Empty {
                if not sess.busy() {
                    break;
                }
                continue;
            }
            st.record(ev);
            if ev.kind == "turn_end" {
                break;
            }
        }
        rc = 130;
    } except Exception as e {
        err(f"jac studio ask: {e}");
        rc = 1;
    } finally {
        sess.stop();
    }
    if sess.agent_session_id {
        st.agent_session_id = sess.agent_session_id;
    }
    st.save();
    out(f"\nsession: {st.id}");
    return rc;
}

impl AskView.chunk(text: str) -> None {
    if not text {
        return;
    }
    sys.stdout.write(text);
    sys.stdout.flush();
    self.in_text = not text.endswith("\n");
}

impl AskView.line(text: str) -> None {
    if self.in_text {
        sys.stdout.write("\n");
        self.in_text = False;
    }
    if text {
        out(text);
    }
}

impl AskView.tool(d: dict[str, any]) -> None {
    tid = str(d.get("id", ""));
    if tid not in self.order {
        self.order.append(tid);
    }
    if d.get("title") {
        self.titles[tid] = str(d["title"]);
    }
    if d.get("kind") {
        self.kinds[tid] = str(d["kind"]);
    }
    rec = self.calls.setdefault(tid, {});
    for k in ["content", "raw_input"] {
        if d.get(k) {
            rec[k] = d[k];
        }
    }
    status = str(d.get("status") or "");
    if status in ["in_progress", "completed", "failed"] and tid not in self.shown {
        self.show_tool(tid, status == "failed");
    } elif status == "failed" {
        self.line(f"  ! failed: {self.titles.get(tid, tid)}");
    }
}

impl AskView.show_tool(tid: str, failed: bool) -> None {
    self.shown.append(tid);
    title = self.titles.get(tid, tid).replace(self.root_dir + os.sep, "");
    mark = "!" if failed else ">";
    tail = "  (failed)" if failed else "";
    self.line(f"  {mark} {title}  [{self.kinds.get(tid, 'other')}]{tail}");
}

impl AskView.flush_tools -> None {
    for tid in self.order {
        if tid not in self.shown {
            self.show_tool(tid, False);
        }
    }
}

impl format_symbol(model: ProjectModel, key: str) -> str {
    nd = model.symbols[key];
    lines = [f"{nd.kind} {nd.key}"];
    if nd.file {
        lines.append(f"  {os.path.relpath(nd.file, model.root_dir)}:{nd.line}");
    }
    sig = getattr(nd, "signature", "") or getattr(nd, "type_str", "");
    if sig {
        lines.append(f"  {sig}");
    }
    hood = model.neighbourhood(key);
    if hood is None {
        return "\n".join(lines);
    }
    for (title, items) in [
        ("members", hood.members),
        ("implemented in", hood.impls),
        ("used by", hood.users),
        ("uses", hood.uses),
        ("walkers that visit it", hood.walkers),
        ("visits", hood.targets)
    ] {
        if items {
            lines.append(f"  {title} ({len(items)}):");
            for it in items[:30] {
                where = f"  {os.path.relpath(it.file, model.root_dir)}{(
                    ":" + str(it.line)
                )
                    if it.line
                    else ""}"
                    if it.file
                    else "";
                lines.append(f"    {it.kind} {it.key}{where}");
            }
        }
    }
    return "\n".join(lines);
}
