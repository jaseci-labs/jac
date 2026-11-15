impl dl_error -> str {
    p = dlerror();
    if p == 0 {
        return "unknown dl error";
    }
    return strdup(p);
}
