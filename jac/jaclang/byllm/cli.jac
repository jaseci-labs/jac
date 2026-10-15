import os;
import sys;
import from jaclang.comptime { name as ct_name }
import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.cli.console { console }

def _human_bytes(n: int) -> str {
    f = float(n);
    for unit in ["B", "KB", "MB", "GB", "TB"] {
        if f < 1024.0 {
            return f"{f:.1f} {unit}";
        }
        f /= 1024.0;
    }
    return f"{f:.1f} PB";
}

def _cmd_model(action: str = "list", alias: str = "") -> int {
    import from jaclang.byllm.local_runtime { LOCAL_MODELS, list_local_aliases }
    import from jaclang.byllm.model_cache {
        force_pull,
        list_downloaded,
        remove_alias,
        get_cache_dir,
        weight_status
    }
    action = (action or "list").strip().lower();

    if action == "list" {
        cached = {`entry["alias"]: `entry for `entry in list_downloaded()};
        console.print(f"Local model cache: {get_cache_dir()}");
        console.print("");
        console.print(f"  {'ALIAS':<22} {'SIZE':>9} {'STATUS':<12} DESCRIPTION");
        console.print(f"  {'-' * 22} {'-' * 9} {'-' * 12} {'-' * 40}");
        labels = {
            "valid": "downloaded",
            "invalid": "invalid",
            "incomplete": "incomplete",
            "missing": "not cached"
        };
        needs_repair: list[str] = [];
        for a in list_local_aliases() {
            spec = LOCAL_MODELS[a];
            state = weight_status(a, spec);
            if state in ("invalid", "incomplete") {
                needs_repair.append(a);
            }
            size = (
                _human_bytes(int(cached[a]["size_bytes"]))
                    if a in cached
                    else f"~{int(spec.get('size_mb', 0))} MB"
            );
            desc = spec.get("description", "");
            console.print(f"  {a:<22} {size:>9} {labels[state]:<12} {desc}");
        }
        for a in needs_repair {
            console.print("");
            console.warning(
                f"'{a}' has invalid or incomplete weights; replace them with "
                f"`jac model pull {a}`"
            );
        }
        return 0;
    }

    if action in ("pull", "rm", "remove", "delete") and not alias {
        console.error(
            f"`jac model {action}` requires an alias",
            hint="try `jac model list` to see available aliases"
        );
        return 2;
    }

    if action == "pull" {
        norm = alias.strip().lower();
        pull_spec = LOCAL_MODELS.get(norm);
        if pull_spec is None {
            console.error(
                f"unknown alias '{alias}'", hint="run `jac model list` for choices"
            );
            return 2;
        }
        state = weight_status(norm, pull_spec);
        if state == "valid" {
            console.info(f"'{norm}' is already downloaded");
            return 0;
        }
        if state == "invalid" {
            console.warning(
                f"cached weights for '{norm}' failed verification; replacing them"
            );
        }
        try {
            path = force_pull(norm, pull_spec);
        } except Exception as e {
            console.error(f"download failed: {e}");
            return 1;
        }
        console.info(f"downloaded {norm} -> {path}");
        return 0;
    }

    if action in ("rm", "remove", "delete") {
        norm = alias.strip().lower();
        try {
            removed = remove_alias(norm);
        } except ValueError as e {
            console.error(f"{e}", hint="run `jac model list` for choices");
            return 2;
        }
        if removed {
            console.info(f"removed cached weights for '{norm}'");
            return 0;
        }
        console.info(f"nothing to remove for '{norm}' (not cached)");
        return 0;
    }

    console.error(f"unknown action '{action}'", hint="use one of: list, pull, rm");
    return 2;
}

comptime SPEC_MODEL: CommandSpec = CommandSpec(
         name="model",
         help="Manage byllm local-model weights (Gemma 4 and friends)",
         args=[
             Arg.create(
                 "action",
                 kind=ArgKind.POSITIONAL,
                 `default="list",
                 help="Action: list, pull, rm"
             ),
             Arg.create(
                 "alias",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="Local-model alias (e.g. gemma-4-e4b). Omit for `list`."
             ),

         ],
         examples=[
             ("jac model list", "Show bundled aliases and download status"),
             ("jac model pull gemma-4-e4b", "Download Gemma 4 E4B GGUF weights"),
             ("jac model rm gemma-4-e4b", "Delete cached weights for an alias"),

         ],
         group="config",
         handler_name=ct_name(model)
     );

def model(action: str = "list", alias: str = "") -> int {
    return _cmd_model(action, alias);
}
