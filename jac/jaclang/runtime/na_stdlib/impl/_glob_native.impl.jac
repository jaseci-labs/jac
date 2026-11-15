impl glob_lexists(path: str) -> bool {
    return lstat(path, _GLOB_STBUF) == 0;
}
