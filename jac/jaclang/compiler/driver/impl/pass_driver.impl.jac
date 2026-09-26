impl CompileProgress.postinit -> None {
    self._listeners = [];
    self._finished_listeners = [];
}

impl CompileProgress.notify(file_path: str) -> None {
    for callback in list(self._listeners) {
        callback(file_path);
    }
}

@contextmanager
impl CompileProgress.track(file_path: str) -> Iterator[None] {
    finished = list(self._finished_listeners);
    self.notify(file_path);
    try {
        yield None;
    } finally {
        for callback in finished {
            if callback in self._finished_listeners {
                callback(file_path);
            }
        }
    }
}

@contextmanager
impl CompileProgress.listen(
    callback: Callable[[str], None], on_finished: Callable[[str], None] | None = None
) -> Iterator[None] {
    self._listeners.append(callback);
    if on_finished is not None {
        self._finished_listeners.append(on_finished);
    }
    try {
        yield None;
    } finally {
        self._listeners.remove(callback);
        if on_finished is not None {
            self._finished_listeners.remove(on_finished);
        }
    }
}
