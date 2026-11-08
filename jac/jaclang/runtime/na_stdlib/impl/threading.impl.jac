impl Lock.init {
    self._mutex = th_alloc(64);
    if not self._mutex {
        raise MemoryError("cannot allocate native mutex");
    }
    rc = th_mutex_init(self._mutex);
    if rc != 0 {
        th_free(self._mutex);
        self._mutex = 0;
        raise RuntimeError("pthread_mutex_init failed: " + str(rc));
    }
}

impl Lock.drop {
    if self._mutex {
        th_mutex_destroy(self._mutex);
        th_free(self._mutex);
        self._mutex = 0;
    }
}

impl Lock.__enter__ -> Lock {
    self.acquire();
    return self;
}

impl Lock.__exit__(exc_type: any, exc: any, tb: any) -> bool {
    self.release();
    return False;
}

impl Lock.acquire(blocking: bool = True, timeout: float = -1.0) -> bool {
    if not self._mutex {
        raise RuntimeError("acquire on uninitialized lock");
    }
    if not blocking and timeout != -1.0 {
        raise ValueError("can't specify timeout for non-blocking acquire");
    }
    if timeout < -1.0 {
        raise ValueError("Invalid value for timeout");
    }
    ok = False;
    if blocking and timeout < 0.0 {
        rc = th_mutex_lock(self._mutex);
        if rc != 0 {
            raise RuntimeError("pthread_mutex_lock failed: " + str(rc));
        }
        ok = True;
    } elif not blocking {
        ok = th_mutex_trylock(self._mutex) == 0;
    } else {
        deadline = time.monotonic() + timeout;
        while True {
            if th_mutex_trylock(self._mutex) == 0 {
                ok = True;
                break;
            }
            if time.monotonic() >= deadline {
                break;
            }
            time.sleep(0.001);
        }
    }
    if ok {
        self._held = True;
        self._owner = th_self();
    }
    return ok;
}

impl Lock.release -> None {
    if not self._mutex or not self._held or self._owner != th_self() {
        raise RuntimeError("cannot release un-acquired lock");
    }

    self._held = False;
    self._owner = 0;
    rc = th_mutex_unlock(self._mutex);
    if rc != 0 {
        raise RuntimeError("pthread_mutex_unlock failed: " + str(rc));
    }
}

impl Event.is_set -> bool {
    self._lock.acquire();
    value = self._flag;
    self._lock.release();
    return value;
}

impl Event.set -> None {
    self._lock.acquire();
    self._flag = True;
    self._lock.release();
}

impl Event.clear -> None {
    self._lock.acquire();
    self._flag = False;
    self._lock.release();
}

impl Event.`wait(timeout: (float | None) = None) -> bool {
    if timeout is None {
        while not self.is_set() {
            time.sleep(0.005);
        }
        return True;
    }
    limit = time.monotonic() + max(0.0, float(timeout));
    while not self.is_set() {
        if time.monotonic() >= limit {
            return False;
        }
        time.sleep(0.005);
    }
    return True;
}

impl Thread.init(
    target: Callable[[], any], daemon: (bool | None) = None, name: (str | None) = None,
) {
    self.target = target;
    self.daemon = daemon if daemon is not None else False;
    self.name = name if name is not None else "native-thread";
}

impl Thread.start -> None {
    _TASKS_LOCK.acquire();
    if self._started {
        _TASKS_LOCK.release();
        raise RuntimeError("threads can only be started once");
    }
    task_id = _NEXT_TASK_ID;
    _NEXT_TASK_ID += 1;
    self._task_id = task_id;
    self._started = True;
    self._alive = True;
    _TASKS[task_id] = self;
    handle = th_spawn(int(ptr(_thread_entry)), task_id);
    if not handle {
        _TASKS.pop(task_id, None);
        self._alive = False;
        _TASKS_LOCK.release();
        raise RuntimeError("pthread_create failed");
    }
    if self.daemon {
        th_detach(handle);
    } else {
        _JOINABLE[task_id] = handle;
        if not _EXIT_HOOK_SET {
            _EXIT_HOOK_SET = True;
            th_at_exit(int(ptr(_join_unfinished)));
        }
    }
    _TASKS_LOCK.release();
}

impl Thread.is_alive -> bool {
    _TASKS_LOCK.acquire();
    alive = self._alive;
    _TASKS_LOCK.release();
    return alive;
}

impl Thread.join(timeout: (float | None) = None) -> None {
    if not self._started {
        raise RuntimeError("cannot join thread before it is started");
    }
    if timeout is None {
        while self.is_alive() {
            time.sleep(0.005);
        }
        return;
    }
    limit = time.monotonic() + max(0.0, float(timeout));
    while self.is_alive() and time.monotonic() < limit {
        time.sleep(0.005);
    }
}

impl _thread_entry(task_id: int) -> int {
    _TASKS_LOCK.acquire();
    task: (Thread | None) = _TASKS.get(task_id);
    _TASKS.pop(task_id, None);
    _TASKS_LOCK.release();
    if task is None {
        return 0;
    }
    try {
        task.target();
    } except BaseException {} finally {
        _TASKS_LOCK.acquire();
        task._alive = False;
        _TASKS_LOCK.release();
    }
    return 0;
}

impl _join_unfinished -> None {
    _TASKS_LOCK.acquire();
    handles: list[int] = [];
    for task_id in _JOINABLE.keys() {
        handles.append(_JOINABLE[task_id]);
    }
    _TASKS_LOCK.release();
    for handle in handles {
        th_join(handle);
    }
}
