impl iskeyword(s: str) -> bool {
    return s in kwlist;
}

impl issoftkeyword(s: str) -> bool {
    return s in softkwlist;
}
