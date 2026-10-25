impl do_poll(fds: list[int], masks: list[int], timeout: int) -> list[int] {
    n: int = len(fds);
    if n == 0 {
        return [int(poll(0, u64(0), i32(timeout)))];
    }
    arr: int = malloc(n * 8);
    k: int = 0;
    while k < n {
        __mem_store_i32(arr + k * 8, i32(fds[k]));
        __mem_store_i32(arr + k * 8 + 4, i32(masks[k]));
        k += 1;
    }
    rc = poll(arr, u64(n), i32(timeout));
    out: list[int] = [int(rc)];
    k = 0;
    while k < n {
        out.append(__mem_load_i32(arr + k * 8 + 4) >> 16);
        k += 1;
    }
    free(arr);
    return out;
}
