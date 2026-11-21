impl time_sleep_ns(ns: int) {
    code: int = int(__jac_sleep_ns(ns));
    if code != 0 {
        raise_errno(code);
    }
}
