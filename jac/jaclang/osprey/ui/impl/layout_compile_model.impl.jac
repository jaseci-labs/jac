impl _wants(phase: str, horizontal: bool) -> bool {
    if phase == "h" {
        return horizontal;
    }
    if phase == "v" {
        return not horizontal;
    }
    return True;
}
