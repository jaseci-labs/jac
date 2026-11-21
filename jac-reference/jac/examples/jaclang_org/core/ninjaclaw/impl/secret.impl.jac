impl service_secret -> str {
    configured = os.environ.get(SECRET_ENV, "").strip();
    if configured {
        return configured;
    }
    path = knowledge_dir() / SECRET_FILE;
    if not path.is_file() {
        fresh = secrets.token_urlsafe(32);
        try {
            fd = os.open(str(path), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600);
            with os.fdopen(fd, "w") as handle {
                handle.write(fresh);
            }
        } except FileExistsError {}
    }
    return path.read_text(encoding="utf-8").strip();
}

impl secret_ok(given: str) -> bool {
    return bool(given) and hmac.compare_digest(given, service_secret());
}
