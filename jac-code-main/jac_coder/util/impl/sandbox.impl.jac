impl set_sandbox_root(sroot: str) -> None {
    _tls.sandbox_root = os.path.realpath(sroot) if sroot else "";
}


impl get_sandbox_root() -> str {
    return getattr(_tls, "sandbox_root", "");
}


impl set_browser_exec(fn: object) -> None {
    _tls.browser_exec = fn;
}


impl get_browser_exec() -> object {
    return getattr(_tls, "browser_exec", None);
}


impl sandbox_path(path: str) -> tuple {
    sroot = get_sandbox_root();
    if not sroot {
        return (path, "");
    }

    if not path or path == "." {
        return (sroot, "");
    }

    if not os.path.isabs(path) {
        path = os.path.join(sroot, path);
    }

    real = os.path.realpath(path);

    try {
        common = os.path.commonpath([sroot, real]);
    } except ValueError {
        return ("", "Error: Access denied — path outside project directory.");
    }

    if common != sroot {
        return ("", "Error: Access denied — path outside project directory.");
    }

    return (real, "");
}
