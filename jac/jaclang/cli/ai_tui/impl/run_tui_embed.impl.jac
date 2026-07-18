import from jaclang.cli.agent_api { AgentRequest }

impl run_tui_embed(req: AgentRequest) -> int {
    import os;
    import from pathlib { Path }
    import from jaclang.cli.console { console }
    import from jaclang.cli.ai_tui.tui_shared {
        _configure_ui_env,
        _embed_byllm_seams,
        _ensure_embed_host,
        _require_tty
    }

    cli_root = Path(str(__file__)).resolve().parent.parent;

    ensured = _ensure_embed_host(cli_root);
    if not ensured.ok {
        console.error(str(ensured.error or "failed to build embed TUI host"));
        if ensured.hint {
            console.error(str(ensured.hint));
        }
        return 1;
    }
    host_bin = str(ensured.path);

    if _require_tty() is None {
        return 1;
    }

    r: any = req;

    _configure_ui_env(r);
    child = dict(os.environ);

    seams = _embed_byllm_seams();
    if seams.get("src") {
        child["JAC_AI_TUI_BYLLM_SRC"] = str(seams["src"]);
    }
    if seams.get("deps") {
        child["JAC_AI_TUI_DEPS"] = str(seams["deps"]);
    }

    if os.environ.get("JAC_STANDALONE") == "1" {
        pyhome = os.environ.get("PYTHONHOME", "").strip();
        if pyhome {
            rt = os.path.dirname(pyhome);
            if rt and os.path.isfile(os.path.join(rt, ".ok")) {
                child["JAC_RT_DIR"] = rt;
            }
        }
    }

    try {
        os.execve(host_bin, [host_bin], child);
    } except Exception as e {
        console.error(f"failed to launch embed TUI host {host_bin}: {e}");
        return 1;
    }
    return 0;
}
