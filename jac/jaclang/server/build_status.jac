import from enum { StrEnum }

enum BuildStatus(StrEnum) {
    OK = "ok",
    COMPILING = "compiling",
    ERROR = "error",
    UNAVAILABLE = "unavailable"
}

obj BuildMonitor {
    static has active: HotReloader | None = None;
}

def get_build_status -> dict[str, any] {
    reloader = BuildMonitor.active;
    if not reloader {
        return {"status": BuildStatus.UNAVAILABLE.value, "diagnostics": []};
    }
    return reloader.build_status();
}
