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

Crucially, we set `JacRuntime.full_target_path` BEFORE creating the
context -- `get_db_path()` / `get_name()` use that to derive the DB
filename (`<stem>.db`), and without it the fallback is `main.db`. That
would make `jac db` point at a different file than `jac enter` created
(which DOES set the path via _discover_config_from_file), and the CLI
would appear to "see no data" in an otherwise healthy DB. jac-scale
overrides the DB path via its config loader and so masks this on
installs that have jac-scale; pure jaclang deployments hit it.
"""
def _load_app_and_get_l3(app_path: str) -> (PersistentMemory | None) {
    try {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        Jac.setup();
        abs_path = os.path.abspath(app_path);
        (base, mod) = os.path.split(abs_path);
        if mod.endswith('.jac') {
            mod = mod[:-4];
        }
        # Match `jac enter`'s path setup so get_db_path() picks the same
        # backing file the app writes to.
        Jac.full_target_path = abs_path;
        if not Jac.base_path_dir {
            Jac.set_base_path(base);
        }
        # Create a fresh CLI execution context so ctx.mem is wired up.
        mach = Jac.create_j_context(user_root=None);
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


"""Entry point — dispatches to the right subcommand."""
impl db(
    action: str = 'inspect',
    sub: str = '',
    arg1: str = '',
    arg2: str = '',
    limit: int = 50,
    app: str = ''
) -> int {
    if action == 'inspect' {
        return _cmd_inspect(app);
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
    console.error(
        f"Unknown action '{action}'",
        hint="expected: inspect, quarantine, alias, recover, recover-all"
    );
    return 1;
}
