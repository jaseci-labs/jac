impl th_alloc(size: int) -> int {
    return malloc(u64(size));
}

impl th_free(ptr: int) {
    if ptr {
        free(ptr);
    }
}

impl th_mutex_init(mutex: int) -> int {
    return pthread_mutex_init(mutex, 0);
}

impl th_mutex_destroy(mutex: int) -> int {
    return pthread_mutex_destroy(mutex);
}

impl th_mutex_lock(mutex: int) -> int {
    return pthread_mutex_lock(mutex);
}

impl th_mutex_trylock(mutex: int) -> int {
    return pthread_mutex_trylock(mutex);
}

impl th_mutex_unlock(mutex: int) -> int {
    return pthread_mutex_unlock(mutex);
}

impl th_spawn(start: int, arg: int) -> int {
    cell = malloc(u64(8));
    if not cell {
        return 0;
    }
    rc = pthread_create(cell, 0, start, arg);
    if rc != 0 {
        free(cell);
        return 0;
    }
    handle = int(ptr[u64](cell).view(1)[0]);
    free(cell);
    return handle;
}

impl th_detach(handle: int) -> int {
    return pthread_detach(handle);
}

impl th_join(handle: int) -> int {
    return pthread_join(handle, 0);
}

impl th_self -> int {
    return pthread_self();
}

impl th_at_exit(handler: int) -> int {
    return atexit(handler);
}
