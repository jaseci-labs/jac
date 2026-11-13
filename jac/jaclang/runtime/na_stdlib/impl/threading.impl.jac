impl Lock.init {
    self._mutex = th_alloc(8);
    if not self._mutex {
        raise MemoryError("cannot allocate native lock state");
    }
    ptr[i64](self._mutex).view(1)[0] = 0;
}

impl Lock.drop {
    if self._mutex {
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
    if timeout < 0.0 and timeout != -1.0 {
        raise ValueError("Invalid value for timeout");
    }
    if not blocking {
        return __atomic_xchg_i64(self._mutex, 1) == 0;
    }
    deadline = time.monotonic() + timeout if timeout >= 0.0 else 0.0;
    while True {
        if __atomic_xchg_i64(self._mutex, 1) == 0 {
            return True;
        }
        if timeout >= 0.0 and time.monotonic() >= deadline {
            return False;
        }
        time.sleep(0.001);
    }
}

impl Lock.release -> None {
    if not self._mutex or __atomic_xchg_i64(self._mutex, 0) == 0 {
        raise RuntimeError("cannot release un-acquired lock");
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
    self._generation += 1;
    self._lock.release();
}

impl Event.clear -> None {
    self._lock.acquire();
    self._flag = False;
    self._lock.release();
}

impl Event.`wait(timeout: (float | None) = None) -> bool {
    self._lock.acquire();
    initial_generation = self._generation;
    ready = self._flag;
    self._lock.release();
    if ready {
        return True;
    }
    limit: float = time.monotonic() + max(0.0, float(timeout))
        if timeout is not None
        else 0.0;
    while True {
        self._lock.acquire();
        ready = self._flag or self._generation != initial_generation;
        self._lock.release();
        if ready {
            return True;
        }
        if timeout is not None and time.monotonic() >= limit {
            return False;
        }
        time.sleep(0.005);
    }
}

impl Thread.init(
    target: Callable[[], any], daemon: (bool | None) = None, name: (str | None) = None,
) {
    self.target = target;
    if daemon is not None {
        self.daemon = daemon;
    } else {
        native_id = th_self();
        _TASKS_LOCK.acquire();
        self.daemon = _THREAD_DAEMON.get(native_id, False);
        _TASKS_LOCK.release();
    }
    self.name = name if name is not None else "native-thread";
}

impl Thread.start -> None {
    th_prepare_threads();
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
    limit: float = time.monotonic() + max(0.0, float(timeout))
        if timeout is not None
        else 0.0;
    while self.is_alive() {
        if timeout is not None and time.monotonic() >= limit {
            return;
        }
        time.sleep(0.005);
    }
    _TASKS_LOCK.acquire();
    handle: (int | None) = _JOINABLE.pop(self._task_id, None);
    _TASKS_LOCK.release();
    if handle is not None {
        th_join(handle);
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
    native_id = th_self();
    _TASKS_LOCK.acquire();
    _THREAD_DAEMON[native_id] = task.daemon;
    _TASKS_LOCK.release();
    try {
        task.target();
    } except BaseException {} finally {
        _TASKS_LOCK.acquire();
        _THREAD_DAEMON.pop(native_id, None);
        task._alive = False;
        _TASKS_LOCK.release();
    }
    return 0;
}

impl _join_unfinished -> None {
    while True {
        _TASKS_LOCK.acquire();
        handles: list[int] = [];
        for task_id in _JOINABLE.keys() {
            handles.append(_JOINABLE[task_id]);
        }
        _JOINABLE.clear();
        _TASKS_LOCK.release();
        if not handles {
            return;
        }
        for handle in handles {
            th_join(handle);
        }
    }
}
