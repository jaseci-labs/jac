import from enum { StrEnum }
import type from jaclang.server.hmr { HotReloader }

enum BuildStatus(StrEnum) {
    OK = "ok",
    COMPILING = "compiling",
    ERROR = "error",
    UNAVAILABLE = "unavailable"
}

obj BuildMonitor {
    static has active: HotReloader | None = None;
}

def get_build_status -> dict {
    reloader = BuildMonitor.active;
    if not reloader {
        return {"status": BuildStatus.UNAVAILABLE.value, "diagnostics": []};
    }
    return reloader.build_status();
}
