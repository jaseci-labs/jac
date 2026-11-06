import from c {
    def pthread_create(thread: bytes, attr: int, start: int, arg: int) -> i32;  def pthread_detach(
        thread: int
    ) -> i32;  def pthread_mutex_init(mutex: int, attr: int) -> i32;  def pthread_mutex_destroy(
        mutex: int
    ) -> i32;  def pthread_mutex_lock(mutex: int) -> i32;  def pthread_mutex_trylock(
        mutex: int
    ) -> i32;  def pthread_mutex_unlock(mutex: int) -> i32;  def malloc(
        size: u64
    ) -> int;  def free(pointer: int) -> None;
}

glob _TASKS: dict[int, Thread] = {},
     _TASKS_LOCK: Lock = Lock(),
     _NEXT_TASK_ID: int = 1;

impl Lock.init {
    self._mutex = malloc(64);
    if not self._mutex {
        raise MemoryError("cannot allocate native mutex");
    }
    rc = pthread_mutex_init(self._mutex, 0);
    if rc != 0 {
        free(self._mutex);
        self._mutex = 0;
        raise RuntimeError("pthread_mutex_init failed: " + str(rc));
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

impl Lock.acquire(blocking: bool, timeout: float) -> bool {
    if not self._mutex {
        raise RuntimeError("acquire on uninitialized lock");
    }
    if blocking and timeout < 0.0 {
        rc = pthread_mutex_lock(self._mutex);
        if rc != 0 {
            raise RuntimeError("pthread_mutex_lock failed: " + str(rc));
        }
        return True;
    }
    if not blocking {
        return pthread_mutex_trylock(self._mutex) == 0;
    }
    deadline = time.monotonic() + timeout;
    while True {
        if pthread_mutex_trylock(self._mutex) == 0 {
            return True;
        }
        if time.monotonic() >= deadline {
            return False;
        }
        time.sleep(0.001);
    }
}

impl Lock.release -> None {
    if not self._mutex or pthread_mutex_unlock(self._mutex) != 0 {
        raise RuntimeError("release of an unlocked native lock");
    }
}

impl Lock.__del__ -> None {
    if self._mutex {
        pthread_mutex_destroy(self._mutex);
        free(self._mutex);
        self._mutex = 0;
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

impl Event.`wait(timeout: (float | None)) -> bool {
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
    target: Callable[[], any], daemon: (bool | None), name: (str | None),
) {
    self.target = target;
    self.daemon = daemon if daemon is not None else False;
    self.name = name if name is not None else "native-thread";
}

def _thread_entry(task_id: int) -> int;

impl Thread.start -> None {
    if self._started {
        raise RuntimeError("threads can only be started once");
    }
    _TASKS_LOCK.acquire();
    task_id = _NEXT_TASK_ID;
    _NEXT_TASK_ID += 1;
    self._task_id = task_id;
    self._started = True;
    self._alive = True;
    _TASKS[task_id] = self;
    thread_mem = malloc(8);
    if not thread_mem {
        _TASKS.pop(task_id, None);
        self._alive = False;
        _TASKS_LOCK.release();
        raise MemoryError("cannot allocate pthread handle");
    }
    rc = pthread_create(thread_mem, 0, ptr(_thread_entry), task_id);
    if rc != 0 {
        free(thread_mem);
        _TASKS.pop(task_id, None);
        self._alive = False;
        _TASKS_LOCK.release();
        raise RuntimeError("pthread_create failed: " + str(rc));
    }
    handle = ptr[u64](thread_mem).view(1)[0];
    pthread_detach(handle);
    free(thread_mem);
    _TASKS_LOCK.release();
}

impl Thread.is_alive -> bool {
    _TASKS_LOCK.acquire();
    alive = self._alive;
    _TASKS_LOCK.release();
    return alive;
}

impl Thread.join(timeout: (float | None)) -> None {
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
    } except Exception {}
    _TASKS_LOCK.acquire();
    task._alive = False;
    _TASKS_LOCK.release();
    return 0;
}
