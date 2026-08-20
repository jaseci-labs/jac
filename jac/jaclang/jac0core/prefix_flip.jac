import os;

glob PREFIX_CLAUSES: tuple[tuple[str, str]] = (
         (
             "disabled-by-env",
             "JAC_PREFIX=off asked for the staged route on this process"
         ),
         (
             "image-unsealed",
             "this image binds no native parser artifact, so no prefix exists"
         ),
         (
             "prefix-entry-absent",
             "the image binds a native parser but exports no prefix entry"
         ),
         (
             "artifact-bind-failure",
             "resolving the prefix entry raised instead of yielding a callable"
         ),
         (
             "source-kind-unsupported",
             "the source is not a .jac module the prefix models"
         ),
         (
             "option-shape-unsupported",
             "no sealed prefix is claimed for this schedule kind and option shape"
         ),
         (
             "annex-present",
             "the module has .impl.jac/.test.jac annexes; the weave is not in "
             "the crossing yet"
         ),
         (
             "absorbed-mod-present",
             "the module carries an absorb import whose tree the crossing "
             "cannot yet receive"
         ),
         (
             "prefix-declined",
             "the crossing itself declined and named its reason in the detail"
         ),
         (
             "crossing-error",
             "the crossing raised; the staged route produced the module"
         ),
         (
             "parity-guard-trip",
             "this module was quarantined after prefix and staged results " "diverged"
         ),

     ),
     _QUIET_CLAUSES: tuple[str] = (
         "image-unsealed",
         "prefix-entry-absent",
         "annex-present",

     ),
     PREFIX_ENV: str = "JAC_PREFIX",
     PREFIX_REPORT_ENV: str = "JAC_PREFIX_REPORT",
     PREFIX_STRICT_ENV: str = "JAC_PREFIX_STRICT",
     COMPILE_STATS_ENV: str = "JAC_COMPILE_STATS",
     _TRUTHY: tuple[str] = ("1", "true", "yes", "on");

glob PREFIX_IR_GEN: tuple[str] = (
         "ASTValidationPass",
         "SymTabBuildPass",
         "DeclImplMatchPass",
         "SemanticAnalysisPass",
         "SemDefMatchPass",
         "CFGBuildPass",

     ),
     PREFIX_IR_GEN_NO_CGEN: tuple[str] = (
         "ASTValidationPass",
         "SymTabBuildPass",
         "DeclImplMatchPass",
         "SemanticAnalysisPass",
         "SemDefMatchPass",
         "CFGBuildPass",
         "JsxIntrinsicGuardPass",

     ),
     PREFIX_SYMTAB_IR: tuple[str] = (
         "ASTValidationPass",
         "SymTabBuildPass",
         "DeclImplMatchPass",

     );

glob _prefix_outcomes: dict[str, dict[str, any]] = {},
     _prefix_quarantine: dict[str, str] = {},
     _prefix_entry_memo: list[tuple[any]] = [],
     _prefix_entry_override: list[any] = [],
     _prefix_handoff: list[tuple[any]] = [],
     _prefix_emitted: list[int] = [];

obj PrefixOutcome {
    has mod_path: str,
        admitted: bool,
        clause: str,
        detail: str,
        claimed: tuple[str],
        executed: tuple[str];
}

obj PrefixFacts {
    has mod_path: str,
        jac_project_root: (str | None),
        access_enforced: bool,
        default_codespace: str;
}

def _env_flag(name: str) -> bool {
    return os.environ.get(name, "").strip().lower() in _TRUTHY;
}

def prefix_disabled -> bool {
    return os.environ.get(PREFIX_ENV, "").strip().lower() in ("off", "0", "no");
}

def prefix_report_enabled -> bool {
    return _env_flag(PREFIX_REPORT_ENV);
}

def prefix_strict_enabled -> bool {
    return _env_flag(PREFIX_STRICT_ENV);
}

def compile_stats_enabled -> bool {
    return _env_flag(COMPILE_STATS_ENV);
}

def prefix_clause_help(clause: str) -> str {
    for (name, text) in PREFIX_CLAUSES {
        if name == clause {
            return text;
        }
    }
    return "unregistered clause";
}

def prefix_clause_names -> tuple[str] {
    return tuple(name for (name, _t) in PREFIX_CLAUSES);
}

def prefix_quiet_clauses -> tuple[str] {
    return _QUIET_CLAUSES;
}

def sealed_prefix_names(kind: str, no_cgen: bool = False) -> tuple[str] {
    if kind == "ir-gen" {
        return PREFIX_IR_GEN_NO_CGEN if no_cgen else PREFIX_IR_GEN;
    }
    if kind == "symtab-ir" {
        return PREFIX_SYMTAB_IR;
    }
    return ();
}

def set_prefix_entry(fn: any) {
    _prefix_entry_override.clear();
    if fn is not None {
        _prefix_entry_override.append(fn);
    }
    _prefix_entry_memo.clear();
}

def clear_prefix_entry {
    _prefix_entry_override.clear();
    _prefix_entry_memo.clear();
}

def prefix_entry -> tuple[any] {
    if _prefix_entry_override {
        return (_prefix_entry_override[0], "", "");
    }
    if _prefix_entry_memo {
        return _prefix_entry_memo[0];
    }
    found: tuple[any] = (None, "", "");
    try {
        import jaclang.jac0core.parser.frontend as _fe;
        fn = _fe?.parse_and_run_prefix;
        if fn is None {
            found = (
                None,
                "prefix-entry-absent",
                "frontend exports no parse_and_run_prefix"
            );
        } else {
            import from jaclang.jac0core.native_brands { native_parser }
            if native_parser("prefix_flip:predicate") is None {
                found = (None, "image-unsealed", "no native parser artifact bound");
            } else {
                found = (fn, "", "");
            }
        }
    } except Exception as exc {
        found = (None, "artifact-bind-failure", f"{type(exc).__name__}: {exc}");
    }
    _prefix_entry_memo.append(found);
    return found;
}

def prefix_facts_for(file_path: str, prog: any) -> PrefixFacts {
    import from jaclang.jac0core.modresolver { find_jac_project_root }
    proj_root: (str | None) = None;
    try {
        proj_root = find_jac_project_root(file_path);
    } except Exception {
        proj_root = None;
    }
    enforce = False;
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        if (cfg and cfg.check) {
            enforce = cfg.check.enforce_access;
        }
    } except Exception {
        enforce = False;
    }
    space = "";
    try {
        import from jaclang.jac0core.codeinfo { effective_default_codespace }
        opts = prog._compile_options if prog is not None else None;
        space = (
            opts.default_codespace
                if (opts is not None and opts.default_codespace)
                else effective_default_codespace()
        );
    } except Exception {
        space = "";
    }
    return PrefixFacts(
        mod_path=file_path,
        jac_project_root=proj_root,
        access_enforced=enforce,
        default_codespace=space
    );
}

def prefix_outcomes_reset {
    _prefix_outcomes.clear();
    _prefix_emitted.clear();
}

def prefix_quarantine(mod_path: str, detail: str) {
    _prefix_quarantine[os.path.realpath(mod_path)] = detail;
}

def prefix_quarantine_clear {
    _prefix_quarantine.clear();
}

def _record(outcome: PrefixOutcome) {
    _prefix_outcomes[os.path.realpath(outcome.mod_path)] = {
        "admitted": outcome.admitted,
        "clause": outcome.clause,
        "detail": outcome.detail,
        "claimed": tuple(outcome.claimed),
        "executed": tuple(outcome.executed)
    };
}

def prefix_snapshot -> dict[str, dict[str, any]] {
    return dict(_prefix_outcomes);
}

def prefix_admit_count -> int {
    return len(
        [
            r
            for r in _prefix_outcomes.values()
            if r["admitted"]
        ]
    );
}

def prefix_fallback_count -> int {
    return len(
        [
            r
            for r in _prefix_outcomes.values()
            if not r["admitted"]
        ]
    );
}

def prefix_loud_fallback_count -> int {
    return len(
        [
            r
            for r in _prefix_outcomes.values()
            if not r["admitted"] and r["clause"] not in _QUIET_CLAUSES
        ]
    );
}

def prefix_native_pass_count -> int {
    total = 0;
    for r in _prefix_outcomes.values() {
        total += len(r["executed"]);
    }
    return total;
}

def prefix_claimed_pass_count -> int {
    total = 0;
    for r in _prefix_outcomes.values() {
        total += len(r["claimed"]);
    }
    return total;
}

def prefix_fallbacks_by_clause -> dict[str, int] {
    counts: dict[str, int] = {};
    for r in _prefix_outcomes.values() {
        if not r["admitted"] {
            counts[r["clause"]] = counts.get(r["clause"], 0) + 1;
        }
    }
    return counts;
}

def prefix_summary_line -> str {
    loud = prefix_loud_fallback_count();
    if loud == 0 and not prefix_report_enabled() {
        return "";
    }
    total = len(_prefix_outcomes);
    if total == 0 {
        return "";
    }
    admitted = prefix_admit_count();
    by_clause = prefix_fallbacks_by_clause();
    shown = ", ".join(
        f"{c}={by_clause[c]}"
        for c in sorted(by_clause)
        if prefix_report_enabled() or c not in _QUIET_CLAUSES
    );
    return (
        f"native prefix: {admitted}/{total} module(s) executed natively; "
        f"{prefix_fallback_count()} fell back ({shown}). "
        f"Set {PREFIX_REPORT_ENV}=1 for per-module detail."
    );
}

def prefix_report_lines -> list[str] {
    lines: list[str] = [];
    for path in sorted(_prefix_outcomes) {
        rec = _prefix_outcomes[path];
        if rec["admitted"] {
            lines.append(
                f"  {path}: prefix ran {len(rec['executed'])} pass(es) "
                f"[{', '.join(rec['executed'])}]"
            );
        } else {
            ran = f" after {len(rec['executed'])} pass(es)" if rec["executed"] else "";
            detail = f" -- {rec['detail']}" if rec["detail"] else "";
            lines.append(
                f"  {path}: fell back{ran} [{rec['clause']}] "
                f"({prefix_clause_help(rec['clause'])}){detail}"
            );
        }
    }
    return lines;
}

def prefix_strict_assert -> None {
    if not prefix_strict_enabled() {
        return;
    }
    count = prefix_fallback_count();
    if count == 0 {
        return;
    }
    nl = chr(10);
    detail = nl.join(prefix_report_lines());
    raise RuntimeError(
        f"{PREFIX_STRICT_ENV}=1 and {count} module(s) did not ride the "
        f"native prefix:{nl}{detail}"
    );
}

def prefix_stats_lines -> list[str] {
    total_mods = len(_prefix_outcomes);
    if total_mods == 0 {
        return ["compile stats: no module reached the prefix router"];
    }
    ran = prefix_native_pass_count();
    claimed = prefix_claimed_pass_count();
    pct = (100.0 * ran / claimed) if claimed else 0.0;
    out: list[str] = [
        f"compile stats: {prefix_admit_count()}/{total_mods} module(s) on the "
        f"native prefix; {ran}/{claimed} claimed prefix pass(es) executed "
        f"natively ({pct:.1f}%)"
    ];
    for path in sorted(_prefix_outcomes) {
        rec = _prefix_outcomes[path];
        names = ", ".join(rec["executed"]) if rec["executed"] else "-";
        out.append(
            f"  {path}: {len(rec['executed'])}/{len(rec['claimed'])} native "
            f"[{names}]"
        );
    }
    return out;
}

def emit_prefix_summary {
    try {
        _emit_prefix_summary();
    } except Exception {
        ;
    }
}

def _emit_prefix_summary {
    if compile_stats_enabled() {
        _emit_lines(prefix_stats_lines());
    }
    loud = prefix_loud_fallback_count();
    reported = _prefix_emitted[0] if _prefix_emitted else -1;
    if loud == reported and not prefix_report_enabled() {
        return;
    }
    line = prefix_summary_line();
    if not line {
        return;
    }
    _prefix_emitted.clear();
    _prefix_emitted.append(loud);
    lines = [line];
    if prefix_report_enabled() {
        lines.extend(prefix_report_lines());
    }
    _emit_lines(lines);
}

def _emit_lines(lines: list[str]) {
    try {
        import sys;
        import from jaclang.cli.console { console as _pf_console }
        for text in lines {
            _pf_console.print(text, style="dim", file=sys.stderr);
        }
    } except Exception {
        ;
    }
}

def drop_executed_prefix(passes: list[any], executed: tuple[str]) -> list[any] {
    n = len(executed);
    if n == 0 {
        return passes;
    }
    head = [p.__name__ for p in passes[:n]];
    if head != list(executed) {
        raise RuntimeError(
            "the native prefix reported passes the schedule does not lead "
            f"with: crossing ran {list(executed)}, schedule head is {head}. "
            "The prefix pin in prefix_flip.sealed_prefix_names and the "
            "schedule in jac0core.compiler have drifted apart."
        );
    }
    return passes[n:];
}

def mark_prefix_provided(prog: any, mod: any, passes: list[any]) {
    provided = prog._analyses_run.get(id(mod));
    if provided is None {
        provided = set();
        prog._analyses_run[id(mod)] = provided;
    }
    for p in passes {
        for tag in (getattr(p, "PROVIDES", ()) or ()) {
            provided.add(tag);
        }
    }
}

def take_prefix_handoff(mod: any) -> tuple[any] {
    if not _prefix_handoff {
        return ((), -1, -1, );
    }
    (mid, executed, err_start, err_end) = _prefix_handoff[0];
    _prefix_handoff.clear();
    if mid != id(mod) {
        return ((), -1, -1, );
    }
    return (executed, err_start, err_end, );
}

def _handoff(mod: any, executed: tuple[str], err_start: int = -1, err_end: int = -1) {
    _prefix_handoff.clear();
    _prefix_handoff.append((id(mod), tuple(executed), err_start, err_end, ));
}

def prefix_span_blocking(prog: any, span: tuple[any], mod_path: str) -> int {
    err_start: int = int(span[1]);
    err_end: int = int(span[2]);
    if err_start < 0 or err_end <= err_start {
        return 0;
    }
    norm = os.path.realpath(mod_path);
    count = 0;
    for alrt in prog.errors_had[err_start:err_end] {
        if alrt.code is None or not alrt.code.blocks_codegen {
            continue;
        }
        try {
            if os.path.realpath(alrt.loc.mod_path) == norm {
                count += 1;
            }
        } except Exception {
            continue;
        }
    }
    return count;
}

def prefix_span_errors(span: tuple[any]) -> int {
    err_start: int = int(span[1]);
    err_end: int = int(span[2]);
    if err_start < 0 or err_end <= err_start {
        return 0;
    }
    return err_end - err_start;
}

def _pre_parse_decline(file_path: str, kind: str, claimed: tuple[str]) -> tuple[str] {
    if prefix_disabled() {
        return ("disabled-by-env", f"{PREFIX_ENV}=off");
    }
    quarantined = _prefix_quarantine.get(os.path.realpath(file_path));
    if quarantined is not None {
        return ("parity-guard-trip", quarantined);
    }
    if not file_path.endswith(".jac") {
        return ("source-kind-unsupported", f"{file_path} is not a .jac module");
    }
    if not claimed {
        return (
            "option-shape-unsupported",
            f"no sealed prefix is claimed for schedule kind {kind or '<none>'}"
        );
    }
    try {
        import from jaclang.jac0core.bccache { discover_annex_files }
        annexes = [
            *discover_annex_files(file_path, ".impl.jac"),
            *discover_annex_files(file_path, ".test.jac")
        ];
    } except Exception {
        annexes = [];
    }
    if annexes {
        return (
            "annex-present",
            f"{len(annexes)} annex source(s) weave into this module"
        );
    }
    (fn, clause, detail) = prefix_entry();
    if fn is None {
        return (clause or "prefix-entry-absent", detail);
    }
    return ();
}

def _staged(source_str: str, file_path: str, prog: any) -> tuple[any] {
    import from jaclang.jac0core.parser { parse as rd_parse }
    return rd_parse(source_str, file_path, prog=prog);
}

def _fall_back(
    source_str: str,
    file_path: str,
    prog: any,
    claimed: tuple[str],
    clause: str,
    detail: str,
    executed: tuple[str] = ()
) -> tuple[any] {
    (mod, had_error) = _staged(source_str, file_path, prog);
    _record(
        PrefixOutcome(
            mod_path=file_path,
            admitted=False,
            clause=clause,
            detail=detail,
            claimed=claimed,
            executed=executed
        )
    );
    _handoff(mod, ());
    return (mod, had_error);
}

def _assert_no_absorb(mod: any, file_path: str) -> str {
    try {
        import jaclang.jac0core.unitree as uni;
        for imp in mod.get_all_sub_nodes(uni.Import) {
            if imp.is_absorb {
                return f"{file_path} carries an absorb import";
            }
        }
    } except Exception {
        return "";
    }
    return "";
}

def parse_with_prefix(
    source_str: str, file_path: str, prog: any, kind: str = "", no_cgen: bool = False
) -> tuple[any] {
    if not kind {
        _prefix_handoff.clear();
        return _staged(source_str, file_path, prog);
    }
    claimed = sealed_prefix_names(kind, no_cgen);
    decline = _pre_parse_decline(file_path, kind, claimed);
    if decline {
        (clause, detail) = decline;
        return _fall_back(source_str, file_path, prog, claimed, clause, detail);
    }
    (`entry, _c, _d) = prefix_entry();
    facts = prefix_facts_for(file_path, prog);
    err_start = len(prog.errors_had) if prog is not None else 0;
    try {
        result = `entry(source_str, file_path, prog, claimed, facts);
    } except Exception as exc {
        return _fall_back(
            source_str,
            file_path,
            prog,
            claimed,
            "crossing-error",
            f"{type(exc).__name__}: {exc}"
        );
    }
    (mod, had_error, executed, clause, detail) = result;
    err_end = len(prog.errors_had) if prog is not None else 0;
    executed = tuple(executed or ());
    if list(executed) != list(claimed[:len(executed)]) {
        raise RuntimeError(
            f"{file_path}: the prefix entry reported {list(executed)}, which "
            f"is not a prefix of the claimed {list(claimed)}"
        );
    }
    if len(executed) < len(claimed) {
        _record(
            PrefixOutcome(
                mod_path=file_path,
                admitted=False,
                clause=clause or "prefix-declined",
                detail=detail,
                claimed=claimed,
                executed=executed
            )
        );
        _handoff(mod, executed, err_start, err_end);
        return (mod, had_error);
    }
    if prefix_report_enabled() or prefix_strict_enabled() {
        why = _assert_no_absorb(mod, file_path);
        if why {
            raise RuntimeError(
                f"{why}, but the prefix ran SymTabBuildPass over it without "
                "the absorbed tree. The crossing must decline with the "
                "absorbed-mod-present clause instead of admitting."
            );
        }
    }
    _record(
        PrefixOutcome(
            mod_path=file_path,
            admitted=True,
            clause="",
            detail="",
            claimed=claimed,
            executed=executed
        )
    );
    _handoff(mod, executed, err_start, err_end);
    return (mod, had_error);
}
