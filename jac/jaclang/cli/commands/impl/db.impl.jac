"""Implementation of `jac db` subcommands.

All subcommands dispatch through the abstract `PersistentMemory` interface
so any L3 backend (SQLite today, MongoDB via jac-scale, plugin-provided
backends in the future) gets the full operator surface without any
CLI-side knowledge of the store.

The CLI needs the user's app loaded so (a) user archetypes register for
recovery attempts, (b) any plugin-configured backend (`MongoBackend` etc.)
wins over the default via the runtime hooks. `--app PATH` selects the
file; if omitted, the single `.jac` file in the current directory is used.
"""

import json;
import os;
import from pathlib { Path }
import from typing { cast }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.memory { PersistentMemory, TieredMemory }
import jaclang.runtimelib.schema_retire as schema_retire;


"""Resolve the user's .jac app path.

Priority: explicit --app → the one and only .jac in cwd → error.
"""
def _resolve_app_path(explicit: str) -> (str | None) {
    if explicit {
        p = Path(explicit);
        if not p.exists() {
            console.error(f"--app path not found: {p}");
            return None;
        }
        return str(p);
    }
    # The cache directory `.jac/` matches `*.jac` because its name ends
    # in `.jac` — filter to regular files.
    jacs = sorted(
        p
        for p in Path.cwd().glob("*.jac")
        if p.is_file()
    );
    if not jacs {
        console.error(
            "No .jac files in the current directory.",
            hint="Pass --app <path/to/app.jac> explicitly."
        );
        return None;
    }
    if len(jacs) > 1 {
        console.error(
            "Multiple .jac files in cwd; pick one with --app:",
            hint=", ".join(j.name for j in jacs)
        );
        return None;
    }
    return str(jacs[0]);
}


"""Import the user's app so user archetypes register AND the right L3
backend is installed via the usual plugin hooks. Returns the live
PersistentMemory backend, or None on error.

We pass `full_target_path` explicitly when constructing the context so
`get_db_path()` / `get_name()` derive the DB filename from this app's
stem. Without it the fallback is `main.db`, which would make `jac db`
point at a different file than `jac enter` created (which DOES set the
path via _discover_config_from_file), and the CLI would appear to "see
no data" in an otherwise healthy DB. jac-scale overrides the DB path
via its config loader and so masks this on installs that have
jac-scale; pure jaclang deployments hit it.
"""
def _load_app_and_get_l3(app_path: str) -> (PersistentMemory | None) {
    try {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        abs_path = os.path.abspath(app_path);
        (base, mod) = os.path.split(abs_path);
        if mod.endswith('.jac') {
            mod = mod[:-4];
        }
        # Match `jac enter`'s path setup so get_db_path() picks the same
        # backing file the app writes to.
        Jac.set_full_target_path(abs_path);
        if not Jac.get_base_path_dir() {
            Jac.set_base_path(base);
        }
        # Create a fresh CLI execution context so ctx.mem is wired up.
        # Pass the seeds explicitly so the ctx's L3 path is locked in at
        # postinit time, immune to later seed mutations.
        mach = Jac.create_j_context(
            user_root=None,
            base_path_dir=Jac.get_base_path_dir(),
            full_target_path=abs_path
        );
        Jac.set_context(mach);
        Jac.jac_import(target=mod, base_path=base, override_name='__main__');
    } except Exception as e {
        console.error(f"Failed to import {app_path}: {e}");
        return None;
    }
    try {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        ctx = Jac.get_context();
        mem = ctx.mem;
        if isinstance(mem, TieredMemory) {
            tiered = cast(TieredMemory, mem);
            if tiered.l3 is None {
                console.error(
                    "No L3 persistent backend is configured.",
                    hint=(
                        "Ensure your app has a base_path set or a plugin "
                        "(e.g. jac-scale) that installs one."
                    )
                );
                return None;
            }
            return tiered.l3;
        }
        if isinstance(mem, PersistentMemory) {
            return cast(PersistentMemory, mem);
        }
        console.error(
            "Runtime memory is not a PersistentMemory backend.",
            hint=f"Got {type(mem).__name__}; expected a PersistentMemory."
        );
    } except Exception as e {
        console.error(f"Failed to resolve backend: {e}");
    }
    return None;
}


def _get_backend(app: str) -> (PersistentMemory | None) {
    app_path = _resolve_app_path(app);
    if not app_path {
        return None;
    }
    return _load_app_and_get_l3(app_path);
}


def _cmd_inspect(app: str) -> int {
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    s = backend.inspect_summary();
    console.print_header(f"Jac DB: {s.get('location', '?')}");
    console.info(
        f"format_version={s.get('format_version')}   "
        f"anchors={s.get('anchors_total')}   "
        f"quarantined={s.get('quarantine_total')}   "
        f"aliases={s.get('aliases_total')}",
        emoji=False
    );
    anchors_by = s.get('anchors_by_type') or [];
    if anchors_by {
        console.print_table(
            headers=["arch_type", "count"],
            rows=[[str(r[0]), str(r[1])] for r in anchors_by],
            title="Anchors"
        );
    }
    qby = s.get('quarantine_by_type') or [];
    if qby {
        console.print_table(
            headers=["arch_type", "count"],
            rows=[[str(r[0]), str(r[1])] for r in qby],
            title="Quarantined"
        );
    }
    return 0;
}


def _cmd_quarantine_list(app: str, limit: int) -> int {
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    rows = backend.list_quarantined(limit);
    if not rows {
        console.success("Nothing quarantined. Everything is clean.");
        return 0;
    }
    console.print_table(
        headers=["id", "arch", "fingerprint", "error", "quarantined_at"],
        rows=[
            [
                (r.get('id') or '')[:8] + '…',
                str(r.get('arch') or ''),
                (r.get('fingerprint') or '')[:8],
                (r.get('error') or '')[:60],
                (r.get('quarantined_at') or '')[:19]
            ] for r in rows
        ],
        title=f"Quarantined (top {len(rows)})"
    );
    return 0;
}


def _cmd_quarantine_show(app: str, row_id: str) -> int {
    if not row_id {
        console.error(
            "Row id required.", hint="jac db quarantine show <full-or-prefix-uuid>"
        );
        return 1;
    }
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    row = backend.show_quarantined(row_id);
    if row is None {
        console.error(f"No quarantined row matching {row_id}");
        return 1;
    }
    if row.get('error') == 'ambiguous' {
        console.error(f"Prefix {row_id} matches multiple rows; use a longer prefix.");
        return 1;
    }
    console.print(json.dumps(row, indent=2, default=str));
    return 0;
}


def _cmd_alias_list(app: str) -> int {
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    rows = backend.list_aliases();
    if not rows {
        console.info("No DB-resident aliases.");
        return 0;
    }
    console.print_table(
        headers=["old_name", "new_name", "created_at"],
        rows=[
            [
                str(r.get('old_name') or ''),
                str(r.get('new_name') or ''),
                (r.get('created_at') or '')[:19]
            ] for r in rows
        ],
        title="Aliases"
    );
    return 0;
}


def _cmd_alias_add(app: str, old_name: str, new_name: str) -> int {
    if not old_name or not new_name {
        console.error(
            "Both old and new names required.",
            hint="jac db alias add old.mod.OldName new.mod.NewName"
        );
        return 1;
    }
    if old_name == new_name {
        console.error("old_name and new_name are identical; alias is a no-op.");
        return 1;
    }
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    backend.add_alias(old_name, new_name);
    console.success(f"Alias registered: {old_name} -> {new_name}");
    console.info(
        "Run `jac db recover-all` to retry any rows currently quarantined "
        "for this class.",
        emoji=False
    );
    return 0;
}


def _cmd_alias_remove(app: str, old_name: str) -> int {
    if not old_name {
        console.error("old_name required.", hint="jac db alias remove old.mod.OldName");
        return 1;
    }
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    removed = backend.remove_alias(old_name);
    if not removed {
        console.warning(f"No alias for {old_name}; nothing to remove.");
        return 1;
    }
    console.success(f"Removed alias: {old_name}");
    return 0;
}


def _cmd_recover(app: str, row_id: str) -> int {
    if not row_id {
        console.error("Row id required.", hint="jac db recover <row-id-or-prefix>");
        return 1;
    }
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    (ok, reason) = backend.recover_one(row_id);
    if ok {
        console.success(f"Recovered: {row_id}");
        return 0;
    }
    console.error(f"Could not recover {row_id}", hint=reason);
    return 1;
}


def _cmd_recover_all(app: str) -> int {
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    (recovered, still_stuck) = backend.recover_all();
    total = recovered + len(still_stuck);
    if total == 0 {
        console.success("No quarantined rows to recover.");
        return 0;
    }
    console.success(f"Recovered {recovered} of {total} quarantined rows.");
    if still_stuck {
        console.warning(f"{len(still_stuck)} rows still quarantined.", emoji=False);
        console.print_table(
            headers=["id", "reason"],
            rows=[
                [(x[0] or '')[:8] + '…', (x[1] or '')[:80]] for x in still_stuck[:20]
            ],
            title="Still quarantined"
        );
    }
    return 0;
}


def _cmd_schema_rules(app: str) -> int {
    # Loading the backend imports the app, which registers archetypes and
    # collects their __jac_schema__ rules — the registry we list from.
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    import from jaclang.runtimelib.schema_rules { repair_mode }
    import jaclang.runtimelib.schema_rules as _rules_mod;
    collected = getattr(_rules_mod, '_collected', {});
    console.print_header("Registered schema drift rules");
    console.info(f"JAC_SCHEMA_REPAIR mode: {repair_mode()}", emoji=False);
    if not collected {
        console.info("No archetype declares a __jac_schema__ hook.");
        return 0;
    }
    rows: list = [];
    for (owner, r) in sorted(collected.items()) {
        for w in r.was_names {
            rows.append([owner, 'was', w]);
        }
        for a in r.aliases {
            rows.append([owner, 'alias', f"{a.stored_name} -> {a.new_name}"]);
        }
        for d in r.drops {
            rows.append([owner, 'drop', d.field_name]);
        }
        for u in r.upgrades {
            rows.append([owner, 'upgrade', getattr(u.fn, '__name__', '<fn>')]);
        }
    }
    console.print_table(
        headers=["archetype", "rule", "detail"], rows=rows, title="Rules"
    );
    return 0;
}


"""Sum every per-label count for one archetype owner."""
def _owner_total(buckets: dict) -> int {
    return sum(buckets.values()) if buckets else 0;
}


def _cmd_migrate(app: str, dry_run: bool) -> int {
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    try {
        rep = backend.schema_migrate(dry_run=dry_run);
    } except NotImplementedError as e {
        console.error("This backend does not support `jac db migrate`.", hint=str(e));
        return 1;
    }
    verb = "Would converge" if rep.get('dry_run') else "Converged";
    repaired_seg = (
        ('would_repair' if dry_run else 'repaired') + '=' + str(rep.get('repaired'))
    );
    console.print_header("Schema migration" + (" (dry run)" if dry_run else ""));
    console.info(
        f"scanned={rep.get('scanned')}   {repaired_seg}   "
        f"clean={rep.get('clean')}   errors={rep.get('errors')}",
        emoji=False
    );
    before = rep.get('before') or {};
    after = rep.get('after') or {};
    rows: list = [];
    for (owner, labels) in sorted(before.items()) {
        for (lbl, count) in sorted(labels.items()) {
            residual = (after.get(owner) or {}).get(lbl, 0);
            rows.append([owner, lbl, str(count), str(residual)]);
        }
    }
    if rows {
        console.print_table(
            headers=["archetype", "rule", verb, "residual"],
            rows=rows,
            title="Rules applied"
        );
    } else {
        console.success("Every document is already at the canonical shape.");
    }
    samples = rep.get('error_samples') or [];
    if samples {
        console.warning(
            f"{len(samples)} document(s) could not be migrated:", emoji=False
        );
        console.print_table(
            headers=["id", "reason"],
            rows=[[str(s[0]), str(s[1])[:80]] for s in samples[:20]],
            title="Migration errors"
        );
    }
    if not dry_run and rep.get('repaired') {
        console.info(
            "Run `jac db schema census` to confirm zero residual, then "
            "`jac db schema retire <Archetype>` to clear the hook from source.",
            emoji=False
        );
    }
    return 0;
}


def _cmd_schema_census(app: str) -> int {
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    try {
        census = backend.schema_census();
    } except NotImplementedError as e {
        console.error(
            "This backend does not support `jac db schema census`.", hint=str(e)
        );
        return 1;
    }
    archetypes = census.get('archetypes') or {};
    unconditional = census.get('unconditional') or {};
    console.print_header("Schema drift census");
    if not archetypes {
        console.info("No archetype declares a __jac_schema__ hook.");
        return 0;
    }
    rows: list = [];
    retireable: list = [];
    for (owner, labels) in sorted(archetypes.items()) {
        owner_unc = unconditional.get(owner) or [];
        for (lbl, count) in sorted(labels.items()) {
            note = "always-on"
                if lbl in owner_unc
                else ("RETIREABLE" if count == 0 else "");
            rows.append([owner, lbl, str(count), note]);
        }
        if _owner_total(labels) == 0 and not owner_unc {
            retireable.append(owner);
        }
    }
    console.print_table(
        headers=["archetype", "rule", "live docs", "note"], rows=rows, title="Census"
    );
    unresolved = census.get('unresolved') or 0;
    if unresolved {
        console.warning(
            f"{unresolved} document(s) have an unresolvable class "
            "(a class-rename concern; see `jac db recover-all`).",
            emoji=False
        );
    }
    if retireable {
        console.success(
            "Fully migrated (every rule reads 0): " + ", ".join(retireable)
        );
        console.info(
            "Clear each from source with `jac db schema retire <Archetype>`.",
            emoji=False
        );
    } else {
        console.info(
            "No archetype is fully migrated yet. Run `jac db migrate` to "
            "converge stored documents first.",
            emoji=False
        );
    }
    return 0;
}


"""Census owners matching `query`: an FQN matches exactly, a bare class name
matches by last segment."""
def _match_owner(owners: list, query: str) -> list {
    if '.' in query {
        return [
            o
            for o in owners
            if o == query
        ];
    }
    return [
        o
        for o in owners
        if o.rsplit('.', 1)[-1] == query
    ];
}


"""Directory to search for the archetype's `.jac` source (the app's folder)."""
def _app_root(app: str) -> str {
    p = _resolve_app_path(app);
    if not p {
        return os.getcwd();
    }
    return os.path.dirname(os.path.abspath(p)) or os.getcwd();
}


def _cmd_schema_retire(app: str, archetype: str, write: bool) -> int {
    if not archetype {
        console.error(
            "Archetype required.",
            hint="jac db schema retire <module.Class | Class> [--write]"
        );
        return 1;
    }
    backend = _get_backend(app);
    if not backend {
        return 1;
    }
    try {
        census = backend.schema_census();
    } except NotImplementedError as e {
        console.error("This backend does not support schema census.", hint=str(e));
        return 1;
    }
    archetypes = census.get('archetypes') or {};
    unconditional = census.get('unconditional') or {};
    owners = _match_owner(list(archetypes.keys()), archetype);
    if not owners {
        console.error(
            f"No __jac_schema__ hook found for '{archetype}'.",
            hint=(
                "known: " + ", ".join(sorted(archetypes.keys()))
                    if archetypes
                    else "no archetype declares a hook"
            )
        );
        return 1;
    }
    if len(owners) > 1 {
        console.error(
            f"'{archetype}' is ambiguous.", hint="matches: " + ", ".join(sorted(owners))
        );
        return 1;
    }
    owner = owners[0];
    labels = archetypes.get(owner) or {};
    total = _owner_total(labels);
    owner_unc = unconditional.get(owner) or [];
    # The safety gate: never delete a rule any live document still needs.
    if total > 0 or owner_unc {
        hint = "Run `jac db migrate`, then confirm `jac db schema census` reads 0.";
        if owner_unc {
            hint += (
                " Always-on upgrade(s) " + ", ".join(owner_unc) + " can never auto-retire; they have no `when` to satisfy."
            );
        }
        console.error(
            f"'{owner}' is not fully migrated "
            f"({total} live doc(s) still rely on it); refusing to edit source.",
            hint=hint
        );
        return 1;
    }
    class_name = owner.rsplit('.', 1)[-1];
    files = schema_retire.hook_source_files(_app_root(app), class_name);
    if not files {
        console.error(
            f"Census says {owner} is retireable, but no .jac source under "
            f"{_app_root(app)} declares its hook.",
            hint="Point at the project with --app, or remove the hook by hand."
        );
        return 1;
    }
    edited: list = [];
    for path in files {
        src = Path(path).read_text(encoding='utf-8');
        (new_src, removed) = schema_retire.strip_hook_from_source(src, class_name);
        if not removed {
            continue;
        }
        edited.append(path);
        console.print_header(("Editing " if write else "Would remove from ") + path);
        for snip in removed {
            console.print(snip.rstrip() + "\n");
        }
        if write {
            Path(path).write_text(new_src, encoding='utf-8');
        }
    }
    if not edited {
        console.warning(
            f"No removable hook for {class_name} found in source (already retired?).",
            emoji=False
        );
        return 1;
    }
    if write {
        console.success(
            f"Retired {class_name}.__jac_schema__ from {len(edited)} file(s)."
        );
        console.info(
            "Re-run your tests and redeploy. With the hook gone, dual-write "
            "stops and no old-shape shadows are written.",
            emoji=False
        );
    } else {
        console.info("Preview only. Re-run with --write to apply.", emoji=False);
    }
    return 0;
}


"""Entry point — dispatches to the right subcommand."""
impl db(
    action: str = 'inspect',
    sub: str = '',
    arg1: str = '',
    arg2: str = '',
    limit: int = 50,
    dry_run: bool = False,
    write: bool = False,
    app: str = ''
) -> int {
    if action == 'inspect' {
        return _cmd_inspect(app);
    }
    if action == 'migrate' {
        return _cmd_migrate(app, dry_run);
    }
    if action == 'quarantine' {
        if sub == 'list' or sub == '' {
            return _cmd_quarantine_list(app, limit);
        }
        if sub == 'show' {
            return _cmd_quarantine_show(app, arg1);
        }
        console.error(
            f"Unknown quarantine sub-action '{sub}'", hint="expected: list, show"
        );
        return 1;
    }
    if action == 'alias' {
        if sub == 'list' or sub == '' {
            return _cmd_alias_list(app);
        }
        if sub == 'add' {
            return _cmd_alias_add(app, arg1, arg2);
        }
        if sub == 'remove' or sub == 'rm' {
            return _cmd_alias_remove(app, arg1);
        }
        console.error(
            f"Unknown alias sub-action '{sub}'", hint="expected: list, add, remove"
        );
        return 1;
    }
    if action == 'recover' {
        return _cmd_recover(app, sub);
    }
    if action == 'recover-all' {
        return _cmd_recover_all(app);
    }
    if action == 'schema' {
        if sub == 'rules' or sub == '' {
            return _cmd_schema_rules(app);
        }
        if sub == 'census' {
            return _cmd_schema_census(app);
        }
        if sub == 'retire' {
            return _cmd_schema_retire(app, arg1, write);
        }
        console.error(
            f"Unknown schema sub-action '{sub}'", hint="expected: rules, census, retire"
        );
        return 1;
    }
    console.error(
        f"Unknown action '{action}'",
        hint="expected: inspect, quarantine, alias, recover, recover-all, schema"
    );
    return 1;
}
