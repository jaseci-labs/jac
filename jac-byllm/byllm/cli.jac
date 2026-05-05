"""`jac model` CLI subcommand for managing bundled local LLM weights.

Provides three actions on the local-model cache:
  - jac model list                  Show bundled aliases + download status
  - jac model pull <alias>          Download weights for an alias
  - jac model rm   <alias>          Delete cached weights for an alias

The download path is the same `ensure_model` used by the runtime, so a
successful `pull` warms the cache and removes the first-run prompt.
"""

import os;
import sys;
import from typing { Any }
import from jaclang.cli.registry { get_registry, CommandRegistry }
import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.console { console }
import from jaclang.jac0core.runtime { hookimpl }

glob registry: CommandRegistry = get_registry();

"""Format a byte count as a human-friendly string (KB / MB / GB)."""
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

"""Implementation of `jac model`.

Dispatches on the positional `action` argument. Returns the process
exit code (0 on success, non-zero on user-visible errors).
"""
def _cmd_model(action: str = "list", alias: str = "") -> int {
    import from byllm.local_runtime { LOCAL_MODELS, list_local_aliases }
    import from byllm.model_cache {
        ensure_model,
        force_pull,
        is_downloaded,
        list_downloaded,
        remove_alias,
        get_cache_dir
    }
    action = (action or "list").strip().lower();

    if action == "list" {
        cached = {entry["alias"]: entry for entry in list_downloaded()};
        console.print(f"Local model cache: {get_cache_dir()}");
        console.print("");
        console.print(f"  {'ALIAS':<22} {'SIZE':>9} {'STATUS':<12} DESCRIPTION");
        console.print(f"  {'-' * 22} {'-' * 9} {'-' * 12} {'-' * 40}");
        for a in list_local_aliases() {
            spec = LOCAL_MODELS[a];
            on_disk = a in cached;
            size = (
                _human_bytes(int(cached[a]["size_bytes"]))
                    if on_disk
                    else f"~{int(spec.get('size_mb', 0))} MB"
            );
            status = "downloaded" if on_disk else "not cached";
            desc = spec.get("description", "");
            console.print(f"  {a:<22} {size:>9} {status:<12} {desc}");
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
        spec = LOCAL_MODELS.get(norm);
        if spec is None {
            console.error(
                f"unknown alias '{alias}'", hint="run `jac model list` for choices"
            );
            return 2;
        }
        if is_downloaded(norm, spec) {
            console.info(f"'{norm}' is already downloaded");
            return 0;
        }
        try {
            path = force_pull(norm, spec);
        } except Exception as e {
            console.error(f"download failed: {e}");
            return 1;
        }
        console.info(f"downloaded {norm} -> {path}");
        return 0;
    }

    if action in ("rm", "remove", "delete") {
        norm = alias.strip().lower();
        if remove_alias(norm) {
            console.info(f"removed cached weights for '{norm}'");
            return 0;
        }
        console.info(f"nothing to remove for '{norm}' (not cached)");
        return 0;
    }

    console.error(f"unknown action '{action}'", hint="use one of: list, pull, rm");
    return 2;
}

# Registration: top-level `jac model` subcommand.
# Decorator runs at module import; the JacCmd hook below ensures byllm
# is loaded into the registry before argparse is finalised.
@registry.command(
    name="model",
    help="Manage byllm local-model weights (Gemma 4 and friends)",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            default="list",
            help="Action: list, pull, rm"
        ),
        Arg.create(
            "alias",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Local-model alias (e.g. gemma-4-e4b). Omit for `list`."
        ),

    ],
    examples=[
        ("jac model list", "Show bundled aliases and download status"),
        ("jac model pull gemma-4-e4b", "Download Gemma 4 E4B GGUF weights"),
        ("jac model rm gemma-4-e4b", "Delete cached weights for an alias"),

    ],
    group="config",
    source="byllm"
)
def model(action: str = "list", alias: str = "") -> int {
    return _cmd_model(action, alias);
}

class JacCmd {
    @hookimpl
    static def create_cmd {
        return;
    }
}
