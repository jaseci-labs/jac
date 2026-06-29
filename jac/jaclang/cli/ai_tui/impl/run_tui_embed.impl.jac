"""Embed TUI host launcher (the sole `jac ai --tui` backend).

`execve` hands the terminal to `jac-ai-tui` wholesale: the host opens its own
controlling tty and runs both the linked-Jac renderer and the embedded-CPython
byLLM agent, so there is no parent-side render loop or env to restore -- the
process image is replaced. The child env is the one contract the host + its
embedded agent read:
  * JAC_AI_UI_* -- project/files/model/session, identical to what the old
    backends set via tui_shared `_configure_ui_env` (the embedded agent's
    `ui_configure()` consumes them);
  * JAC_AI_TUI_BYLLM_SRC / JAC_AI_TUI_DEPS -- byLLM runtime sys.path seams,
    located by find_spec so a fused parent (no byLLM bundled) still points the
    embedded interpreter at a usable byLLM;
  * JAC_AI_TUI_EMBED_REAL=1 -- select the real agent over the boot stub;
  * JAC_RT_DIR -- only when WE run on a fused runtime: the payload-baked host is
    trailerless and borrows our already-materialized rt instead of self-booting.
"""

import from jaclang.cli.agent_api { AgentRequest }

impl run_tui_embed(req: AgentRequest) -> int {
    import os;
    import sys;
    import from pathlib { Path }
    import from jaclang.cli.console { console }
    import from jaclang.cli.ai_tui.tui_shared {
        _configure_ui_env,
        _embed_byllm_seams,
        _ensure_embed_host,
        _require_tty
    }

    if sys.platform == "win32" {
        console.error(
            "jac ai --tui is not supported on Windows yet "
            "(the embed host is built for Linux/macOS)."
        );
        return 1;
    }

    cli_root = Path(__file__).resolve().parent.parent;

    ensured = _ensure_embed_host(cli_root);
    if not ensured.get("ok") {
        console.error(str(ensured.get("error", "failed to build embed TUI host")));
        hint = str(ensured.get("hint", ""));
        if hint {
            console.error(hint);
        }
        return 1;
    }
    host_bin = str(ensured["path"]);

    # Pre-flight the tty so a non-interactive invocation gets the shared, friendly
    # error here rather than a cryptic failure inside the host's tty_open.
    if _require_tty() is None {
        return 1;
    }

    r: any = req;

    _configure_ui_env(r);
    child = dict(os.environ);
    child["JAC_AI_TUI_EMBED_REAL"] = "1";

    # byLLM runtime seams (find_spec, never import).
    seams = _embed_byllm_seams();
    if seams.get("src") {
        child["JAC_AI_TUI_BYLLM_SRC"] = str(seams["src"]);
    }
    if seams.get("deps") {
        child["JAC_AI_TUI_DEPS"] = str(seams["deps"]);
    }

    # JAC_RT_DIR: only when we run on a fused runtime. embed.zig set PYTHONHOME to
    # <rt>/python; the trailerless payload host reuses that rt (gated on .ok) so it
    # needn't carry a second copy. Unset in dev, where the host is self-contained.
    if os.environ.get("JAC_STANDALONE") == "1" {
        pyhome = os.environ.get("PYTHONHOME", "").strip();
        if pyhome {
            rt = os.path.dirname(pyhome);
            if rt and os.path.isfile(os.path.join(rt, ".ok")) {
                child["JAC_RT_DIR"] = rt;
            }
        }
    }

    # Replace this process: the host takes over stdin/stdout/stderr (the tty).
    try {
        os.execve(host_bin, [host_bin], child);
    } except Exception as e {
        console.error(f"failed to launch embed TUI host {host_bin}: {e}");
        return 1;
    }
    return 0;  # unreachable: execve does not return on success
}
