impl platform_cache_home(home: str) -> str {
    if int(__jac_platform_id()) == 1 {
        return home + "/Library/Caches/jac";
    }
    return home + "/.cache/jac";
}
