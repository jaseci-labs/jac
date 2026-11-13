impl get_build_status -> dict[str, any] {
    reloader = BuildMonitor.active;
    if not reloader {
        return {"status": BuildStatus.UNAVAILABLE.value, "diagnostics": []};
    }
    return reloader.build_status();
}
