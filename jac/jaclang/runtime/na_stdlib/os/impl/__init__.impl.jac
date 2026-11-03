impl _Walker.__iter__ -> _Walker {
    return self;
}

impl _Walker.scan(top: str) -> (_WalkFrame | None) {
    try {
        entries = directory_entries(top);
    } except OSError as err {
        handler = self.onerror;
        if handler is not None {
            handler(err);
        }
        return None;
    }
    frame = _WalkFrame(top=top);
    for ent in entries {
        full = join(top, ent.name);
        is_dir = ent.kind == DIRENT_DIRECTORY;
        if ent.kind == DIRENT_LINK or ent.kind == DIRENT_UNKNOWN {
            is_dir = isdir(full);
        }
        if is_dir {
            frame.dirs.append(ent.name);
            if ent.kind == DIRENT_LINK {
                self.links.add(full);
            }
        } else {
            frame.files.append(ent.name);
        }
    }
    return frame;
}

impl _Walker.descend_from(frame: _WalkFrame) {
    index = len(frame.dirs) - 1;
    while index >= 0 {
        child = join(frame.top, frame.dirs[index]);
        if self.followlinks or child not in self.links {
            self.pending.append(child);
        }
        index -= 1;
    }
}

impl _Walker.__next__ -> tuple[str, list[str], list[str]] {
    if self.emitted is not None {
        self.descend_from(self.emitted);
        self.emitted = None;
    }
    while self.pending {
        top = self.pending.pop();
        frame = self.scan(top);
        if frame is None {
            continue;
        }
        self.emitted = frame;
        return (frame.top, frame.dirs, frame.files);
    }
    raise StopIteration();
}

impl _walk_bottom_up(
    top: str,
    onerror: (Callable[[OSError], None] | None),
    followlinks: bool,
    out: list[tuple[str, list[str], list[str]]]
) {
    scanner = _Walker(onerror=onerror, followlinks=followlinks);
    frame = scanner.scan(top);
    if frame is None {
        return;
    }
    for name in frame.dirs {
        child = join(top, name);
        if followlinks or child not in scanner.links {
            _walk_bottom_up(child, onerror, followlinks, out);
        }
    }
    out.append((frame.top, frame.dirs, frame.files));
}

impl walk(
    top: str,
    topdown: bool = True,
    onerror: (Callable[[OSError], None] | None) = None,
    followlinks: bool = False
) -> Iterator[tuple[str, list[str], list[str]]] {
    if not topdown {
        rows: list[tuple[str, list[str], list[str]]] = [];
        _walk_bottom_up(top, onerror, followlinks, rows);
        return iter(rows);
    }
    return _Walker(
        topdown=True, onerror=onerror, followlinks=followlinks, pending=[top]
    );
}
