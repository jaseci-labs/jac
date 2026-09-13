import from contextvars { ContextVar }


glob _effective_codespace_ctx: ContextVar[str] = ContextVar(
         "jac_effective_default_codespace"
     ),
     _closure_cap_ctx: ContextVar[int] = ContextVar("jac_native_closure_cap"),
     _native_target_ctx: ContextVar[str | None] = ContextVar("jac_native_target");

def set_effective_default_codespace(value: str) {
    _effective_codespace_ctx.set(value);
}

def get_effective_default_codespace_override -> str {
    return _effective_codespace_ctx.get('');
}

def effective_default_codespace -> str {
    cur = _effective_codespace_ctx.get('');
    if cur {
        return cur;
    }
    try {
        import from jaclang.project.config { get_config, PlacementConfig }
        cfg = get_config();
        if cfg is not None {
            return cfg.placement.default_codespace;
        }
        return PlacementConfig().default_codespace;
    } except Exception {
        return "server";
    }
}

def set_native_closure_cap(value: int) {
    _closure_cap_ctx.set(value);
}

def get_native_closure_cap_override -> int {
    return _closure_cap_ctx.get(0);
}

def effective_native_closure_cap -> int {
    cur = _closure_cap_ctx.get(0);
    if cur > 0 {
        return cur;
    }
    try {
        import from jaclang.project.config { get_config, BuildConfig }
        cfg = get_config();
        if cfg is not None {
            return cfg.build.native_closure_cap;
        }
        return BuildConfig().native_closure_cap;
    } except Exception {
        return 256;
    }
}

def set_native_target_override(triple: str | None) -> (str | None) {
    prev = _native_target_ctx.get(None);
    _native_target_ctx.set(triple);
    return prev;
}

def effective_native_target -> str {
    cur = _native_target_ctx.get(None);
    if cur is not None {
        return cur;
    }
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        return cfg.native.target if cfg is not None else "";
    } except Exception {
        return "";
    }
}

def native_target_os -> str {
    import sys;
    _t = effective_native_target();
    if _t {
        if ("darwin" in _t) or ("apple" in _t) {
            return "darwin";
        }
        if ("windows" in _t) or ("msvc" in _t) {
            return "windows";
        }
        return "linux";
    }
    _s = sys.platform;
    if _s == "darwin" {
        return "darwin";
    }
    if _s == "win32" {
        return "windows";
    }
    return "linux";
}
