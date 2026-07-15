"""`jac model` CLI: manage local LLM weights and the model daemon.

Actions:
  - jac model list                Show manifest aliases + download status
  - jac model show <alias>        Print an alias's manifest entry + launch args
  - jac model pull <alias>        Download weights for an alias (owns consent)
  - jac model rm   <alias>        Delete cached weights for an alias
  - jac model run  <alias>        Pull-if-needed, start the daemon, run a prompt
  - jac model serve               Run the model daemon (--daemon to detach)
  - jac model stop                Stop the running model daemon (and its runners)
  - jac model ps                  Show running llama-server runners
  - jac model refresh             Fetch the remote model index (manifest_url)

The daemon never downloads; only `pull` and `run` fetch weights (the consent
ladder lives in `byllm.model_cache`).
"""

import os;
import sys;
import from jaclang.cli.registry { get_registry, CommandRegistry }
import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.console { console }

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

def _cmd_list -> int {
    import from jaclang.byllm.serve.manifest { list_aliases, resolve_entry, to_cache_spec }
    import from jaclang.byllm.model_cache { is_downloaded, list_downloaded, get_cache_dir }
    cached = {row["alias"]: row for row in list_downloaded()};
    console.print(f"Local model cache: {get_cache_dir()}");
    console.print("");
    console.print(f"  {'ALIAS':<22} {'SIZE':>9} {'STATUS':<12} DESCRIPTION");
    console.print(f"  {'-' * 22} {'-' * 9} {'-' * 12} {'-' * 40}");
    for a in list_aliases() {
        entry = resolve_entry(a);
        spec = to_cache_spec(entry);
        on_disk = is_downloaded(a, spec);
        size = (
            _human_bytes(int(cached[a]["size_bytes"]))
                if a in cached
                else f"~{int(spec.get('size_mb', 0))} MB"
        );
        status = "downloaded" if on_disk else "not cached";
        console.print(f"  {a:<22} {size:>9} {status:<12} {entry.get('description', '')}");
    }
    return 0;
}

def _cmd_show(alias: str) -> int {
    import json;
    import from jaclang.byllm.serve.manifest { resolve_entry, to_cache_spec }
    import from jaclang.byllm.serve.runner { llama_server_argv }
    import from jaclang.byllm.model_cache { is_downloaded, gguf_path }
    import from jaclang.byllm.config_loader { get_byllm_config }
    norm = alias.strip().lower();
    try {
        entry = resolve_entry(norm);
    } except ValueError as ve {
        console.error(str(ve));
        return 2;
    }
    spec = to_cache_spec(entry);
    dl = is_downloaded(norm, spec);
    console.print(f"alias: {norm}");
    console.print(json.dumps(entry, indent=2));
    console.print(f"downloaded: {dl}");
    if dl {
        local_cfg = get_byllm_config().get_local_config();
        argv = llama_server_argv(
            "llama-server", norm, str(gguf_path(norm, spec)), 0, local_cfg, entry, False
        );
        console.print("would launch: " + " ".join(argv));
    }
    return 0;
}

def _cmd_pull(alias: str) -> int {
    import from jaclang.byllm.serve.manifest { resolve_entry, to_cache_spec }
    import from jaclang.byllm.model_cache { force_pull, is_downloaded }
    norm = alias.strip().lower();
    try {
        entry = resolve_entry(norm);
    } except ValueError as ve {
        console.error(str(ve));
        return 2;
    }
    spec = to_cache_spec(entry);
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

def _cmd_rm(alias: str) -> int {
    import from jaclang.byllm.model_cache { remove_alias }
    norm = alias.strip().lower();
    if remove_alias(norm) {
        console.info(f"removed cached weights for '{norm}'");
        return 0;
    }
    console.info(f"nothing to remove for '{norm}' (not cached)");
    return 0;
}

def _cmd_serve(serve_port: int, background: bool) -> int {
    import from jaclang.byllm.serve.client { _read_portfile, _daemon_healthy }
    if background {
        import from jaclang.byllm.serve.client { ensure_daemon }
        try {
            port = ensure_daemon();
        } except Exception as e {
            console.error(f"failed to start model daemon: {e}");
            return 1;
        }
        console.info(f"model daemon running on 127.0.0.1:{port}");
        return 0;
    }
    # A second foreground daemon would overwrite the pid/port files and strand
    # the first one (plus its loaded runners) -- refuse while one is healthy.
    existing = _read_portfile();
    if existing and _daemon_healthy(existing) {
        console.error(
            f"a model daemon is already running on 127.0.0.1:{existing}",
            hint="use it as-is, or stop it first with `jac model stop`"
        );
        return 1;
    }
    import from jaclang.byllm.serve.daemon { ModelDaemon }
    import from jaclang.byllm.config_loader { get_byllm_config }
    serve_cfg = dict(get_byllm_config().get_serve_config());
    if serve_port > 0 {
        serve_cfg["serve_port"] = serve_port;
    }
    md = ModelDaemon(serve_cfg=serve_cfg);
    console.info("starting jac model daemon (Ctrl-C to stop)");
    try {
        md.serve();
    } except KeyboardInterrupt {
        md.shutdown();
        console.print("");
        console.info("model daemon stopped");
    }
    return 0;
}

def _cmd_run(alias: str, prompt: str) -> int {
    import from jaclang.byllm.serve.manifest { resolve_entry, to_cache_spec }
    import from jaclang.byllm.model_cache { ensure_model }
    import from jaclang.byllm.serve.client { ensure_daemon }
    norm = alias.strip().lower();
    try {
        entry = resolve_entry(norm);
    } except ValueError as ve {
        console.error(str(ve));
        return 2;
    }
    spec = to_cache_spec(entry);
    # `jac model run` owns consent: pull-if-needed (the `ollama run` analog).
    try {
        ensure_model(norm, spec);
    } except Exception as e {
        console.error(f"{e}");
        return 1;
    }
    try {
        port = ensure_daemon();
    } except Exception as e {
        console.error(f"failed to start model daemon: {e}");
        return 1;
    }
    if not prompt {
        console.info(
            f"model '{norm}' ready on 127.0.0.1:{port}. Pass --prompt to run a completion."
        );
        return 0;
    }
    import json;
    import urllib.request;
    body = json.dumps(
        {"model": norm, "messages": [{"role": "user", "content": prompt}]}
    ).encode();
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/v1/chat/completions",
        data=body, headers={"Content-Type": "application/json"}, method="POST"
    );
    try {
        with urllib.request.urlopen(req, timeout=600) as r {
            resp = json.loads(r.read());
        }
    } except Exception as e {
        console.error(f"completion failed: {e}");
        return 1;
    }
    console.print(resp["choices"][0]["message"]["content"]);
    return 0;
}

"""Stop the running daemon via SIGTERM; its handler shuts runners down too."""
def _cmd_stop -> int {
    import signal;
    import time;
    import from jaclang.byllm.serve.paths { daemon_pidfile, daemon_portfile }
    pid = None;
    try {
        pid = int(daemon_pidfile().read_text().strip());
    } except Exception {}
    if pid is None {
        console.info("no model daemon is running");
        return 0;
    }
    try {
        os.kill(pid, signal.SIGTERM);
    } except ProcessLookupError {
        # Daemon died without cleanup; clear the stale run files.
        try {
            daemon_pidfile().unlink(missing_ok=True);
            daemon_portfile().unlink(missing_ok=True);
        } except Exception {}
        console.info("no model daemon is running (cleared stale pid file)");
        return 0;
    } except Exception as e {
        console.error(f"could not stop model daemon (pid {pid}): {e}");
        return 1;
    }
    deadline = time.time() + 15.0;
    while time.time() < deadline {
        try {
            os.kill(pid, 0);
        } except ProcessLookupError {
            console.info(f"model daemon (pid {pid}) stopped");
            return 0;
        }
        time.sleep(0.2);
    }
    console.error(
        f"model daemon (pid {pid}) did not exit within 15s",
        hint=f"inspect it, or `kill -9 {pid}` as a last resort"
    );
    return 1;
}

"""Fetch [byllm.serve].manifest_url into the model-index cache layer."""
def _cmd_refresh -> int {
    import from jaclang.byllm.serve.manifest { refresh_index }
    import from jaclang.byllm.config_loader { get_byllm_config }
    url = str(get_byllm_config().get_serve_config().get("manifest_url", ""));
    if not url {
        console.info(
            "no [byllm.serve].manifest_url configured; nothing to refresh"
        );
        return 0;
    }
    try {
        n = refresh_index(url);
    } except Exception as e {
        console.error(f"model index refresh failed: {e}");
        return 1;
    }
    console.info(f"refreshed model index ({n} models) from {url}");
    return 0;
}

def _cmd_ps -> int {
    import json;
    import urllib.request;
    import from jaclang.byllm.serve.client { _read_portfile, _daemon_healthy }
    port = _read_portfile();
    if not port or not _daemon_healthy(port) {
        console.info("no model daemon is running");
        return 0;
    }
    try {
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/api/ps", timeout=3) as r {
            runners = json.loads(r.read()).get("runners", []);
        }
    } except Exception as e {
        console.error(f"model daemon did not answer /api/ps: {e}");
        return 1;
    }
    if not runners {
        console.print("no runners loaded");
        return 0;
    }
    console.print(f"  {'ALIAS':<22} {'PORT':>6} {'VARIANT':<8} {'IDLE(s)':>8} STATE");
    for row in runners {
        state = "alive" if row.get("alive") else "dead";
        console.print(
            f"  {row['alias']:<22} {row['port']:>6} {row.get('variant', ''):<8} "
            f"{row.get('idle_s', 0):>8} {state}"
        );
    }
    return 0;
}

"""Implementation of `jac model`. Returns the process exit code."""
def _cmd_model(
    action: str = "list",
    alias: str = "",
    serve_port: int = 0,
    daemon: bool = False,
    prompt: str = ""
) -> int {
    action = (action or "list").strip().lower();

    if action in ("pull", "rm", "remove", "delete", "show", "run") and not alias {
        console.error(
            f"`jac model {action}` requires an alias",
            hint="try `jac model list` to see available aliases"
        );
        return 2;
    }

    if action == "list" {
        return _cmd_list();
    } elif action == "show" {
        return _cmd_show(alias);
    } elif action == "pull" {
        return _cmd_pull(alias);
    } elif action in ("rm", "remove", "delete") {
        return _cmd_rm(alias);
    } elif action == "serve" {
        return _cmd_serve(serve_port, daemon);
    } elif action == "stop" {
        return _cmd_stop();
    } elif action == "run" {
        return _cmd_run(alias, prompt);
    } elif action == "ps" {
        return _cmd_ps();
    } elif action == "refresh" {
        return _cmd_refresh();
    }
    console.error(
        f"unknown action '{action}'",
        hint="use one of: list, show, pull, rm, run, serve, stop, ps, refresh"
    );
    return 2;
}

# Registration: top-level `jac model` subcommand. The decorator runs when this
# module is imported by register_feature_commands at CLI startup.
@registry.command(
    name="model",
    help="Manage byllm local models and the model daemon",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            default="list",
            help="Action: list, show, pull, rm, run, serve, stop, ps, refresh"
        ),
        Arg.create(
            "alias",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Local-model alias (e.g. gemma-4-e4b). Omit for list/serve/stop/ps/refresh."
        ),
        Arg.create(
            "serve_port",
            kind=ArgKind.OPTION,
            typ=int,
            default=0,
            help="Daemon port for `serve` (0 = auto). Not named --port on purpose."
        ),
        Arg.create(
            "daemon",
            kind=ArgKind.FLAG,
            default=False,
            help="For `serve`: start the daemon detached in the background."
        ),
        Arg.create(
            "prompt",
            kind=ArgKind.OPTION,
            typ=str,
            default="",
            help="For `run`: a prompt to send to the model."
        )
    ],
    examples=[
        ("jac model list", "Show manifest aliases and download status"),
        ("jac model pull gemma-4-e4b", "Download Gemma 4 E4B GGUF weights"),
        ("jac model run gemma-4-e4b --prompt 'hi'", "Pull-if-needed, serve, and run a prompt"),
        ("jac model serve --daemon", "Start the model daemon in the background"),
        ("jac model stop", "Stop the model daemon and its runners"),
        ("jac model ps", "Show running llama-server runners")
    ],
    group="config"
)
def model(
    action: str = "list",
    alias: str = "",
    serve_port: int = 0,
    daemon: bool = False,
    prompt: str = ""
) -> int {
    return _cmd_model(action, alias, serve_port, daemon, prompt);
}
