# Captured inputs shared by compilation, indexing and editor queries.
import os;
import hashlib;
import from pathlib { Path }
import from contextlib { contextmanager }

def source_bytes(path: str) -> bytes | None {
    try {
        return Path(path).read_bytes();
    } except OSError {
        return None;
    }
}

def content_digest(data: bytes | None) -> str | None {
    return hashlib.sha256(data).hexdigest() if data is not None else None;
}

obj InputManifest {
    has files: dict[str, str | None],
        annexes: dict[str, list[str]];

    def is_current(store: SourceStore | None = None) -> bool {
        return next(self.changed_paths(store), None) is None;
    }

    def changed_paths(store: SourceStore | None = None) -> Iterator[str] {
        for (path, digest) in self.files.items() {
            snapshot = store.snapshot if store is not None else None;
            actual = snapshot.digest(path)
                if snapshot is not None
                else content_digest(
                    store.overrides[path].encode('utf-8')
                        if store is not None and path in store.overrides
                        else source_bytes(path)
                );
            if actual != digest {
                yield path;
            }
        }
        discovery = store if store is not None else SourceStore();
        for (path, paths) in self.annexes.items() {
            if discovery.annex_paths(path) != paths {
                yield path;
            }
        }
    }

    def digest -> str {
        import json;
        return hashlib.sha256(json.dumps(self.to_dict(), sort_keys=True).encode('utf-8')).hexdigest();
    }

    def to_dict -> dict[str, any] {
        return {'files': self.files, 'annexes': self.annexes};
    }

    static def from_dict(data: dict[str, any]) -> InputManifest {
        return InputManifest(
            {
                str(path): str(value) if value is not None else None
                for (path, value) in data['files'].items()
            },
            {
                str(path): [str(item) for item in paths]
                for (path, paths) in data['annexes'].items()
            }
        );
    }
}

obj InputReads {
    has files: set[str] = set(),
        annexes: set[str] = set();
}

obj SourceSnapshot {
    has overrides: dict[str, str],
        files: dict[str, str] = {},
        disk: dict[str, bytes | None] = {},
        annex_paths: dict[str, list[str]] = {},
        modules: set[str] = set(),
        read_paths: set[str] = set(),
        digests: dict[str, str | None] = {},
        read_sets: list[InputReads] = [];

    @contextmanager
    def scope -> Iterator[SourceSnapshot] {
        self.read_sets.append(InputReads());
        try {
            yield self;
        } finally {
            self.read_sets.pop();
        }
    }

    def record_read(path: str) {
        self.read_paths.add(path);
        for reads in self.read_sets {
            reads.files.add(path);
        }
    }

    def record_annex(path: str) {
        for reads in self.read_sets {
            reads.annexes.add(path);
        }
    }

    def exists(path: str) -> bool {
        return self.digest(os.path.realpath(path)) is not None;
    }

    def digest(path: str) -> str | None {
        self.record_read(path);
        if path not in self.digests {
            if path not in self.overrides {
                self.watch(path);
            }
            self.digests[path] = content_digest(
                self.overrides[path].encode('utf-8')
                    if path in self.overrides
                    else self.disk[path]
            );
        }
        return self.digests[path];
    }

    def manifest -> InputManifest {
        reads = self.read_sets[-1] if self.read_sets else None;
        paths = reads.files if reads is not None else self.disk.keys() | self.read_paths;
        annexes = reads.annexes if reads is not None else self.annex_paths.keys();
        return InputManifest(
            {path: self.digest(path) for path in paths},
            {path: list(self.annex_paths[path]) for path in annexes}
        );
    }

    def watch(path: str) {
        self.record_read(path);
        if path not in self.disk {
            self.disk[path] = source_bytes(path);
        }
    }

    def watch_configuration(path: str) {
        for directory in Path(path).parents {
            for name in ('jac.toml', 'jac.lock', '.env', '.jacignore') {
                self.watch(str(directory / name));
            }
        }
    }

    def read_bytes(path: str) -> bytes {
        path = os.path.realpath(path);
        self.record_read(path);
        if path in self.overrides {
            return self.overrides[path].encode('utf-8');
        }
        self.watch(path);
        data = self.disk[path];
        if data is None {
            raise OSError(f'Could not read file {path}');
        }
        return data;
    }

    def read(path: str) -> str {
        import from jaclang.project.source { decode_source }
        path = os.path.realpath(path);
        self.record_read(path);
        if path in self.overrides {
            return self.overrides[path];
        }
        if path not in self.files {
            self.files[path] = decode_source(self.read_bytes(path), path);
        }
        return self.files[path];
    }

    def is_current(store: SourceStore) -> bool {
        return self.manifest().is_current(SourceStore(dict(store.overrides)));
    }
}

obj SourceStore {
    has overrides: dict[str, str] = {},
        snapshot: SourceSnapshot | None = None;

    @contextmanager
    def capture -> Iterator[SourceSnapshot] {
        import from jaclang.project.source { SourceAccess, source_access }
        if self.snapshot is not None {
            with self.snapshot.scope() as captured {
                yield captured;
            }
            return;
        }
        captured = SourceSnapshot(dict(self.overrides));
        self.snapshot = captured;
        token = source_access.set(
            SourceAccess(captured.read, self.annexes, captured.exists, captured.read_bytes)
        );
        try {
            with captured.scope() {
                yield captured;
            }
        } finally {
            source_access.reset(token);
            self.snapshot = None;
        }
    }

    def record_module(path: str) {
        if self.snapshot is not None {
            path = os.path.realpath(path);
            self.snapshot.modules.add(path);
            self.snapshot.record_read(path);
            self.snapshot.watch_configuration(path);
            if path not in self.snapshot.overrides {
                self.snapshot.watch(path);
            }
        }
    }

    def read(path: str) -> str {
        import from jaclang.project.source { read_file_with_encoding }
        if self.snapshot is not None {
            return self.snapshot.read(path);
        }
        source = self.overrides.get(os.path.realpath(path));
        return source if source is not None else read_file_with_encoding(path);
    }

    def discover_annex_paths(path: str) -> list[str] {
        import from jaclang.compiler.driver.bccache { discover_base_file }
        import from jaclang.project.source { disk_annex_paths }
        path = os.path.realpath(path);
        if not path.endswith('.jac') or discover_base_file(path) is not None {
            return [];
        }
        paths = set(disk_annex_paths(path));
        paths.update(
            candidate
            for candidate in self.overrides
            if discover_base_file(candidate) == path
        );
        return sorted(paths);
    }

    def annex_paths(path: str) -> list[str] {
        path = os.path.realpath(path);
        snapshot = self.snapshot;
        if snapshot is None {
            paths = self.discover_annex_paths(path);
        } else {
            snapshot.record_annex(path);
            if path not in snapshot.annex_paths {
                snapshot.annex_paths[path] = self.discover_annex_paths(path);
            }
            paths = snapshot.annex_paths[path];
        }
        return paths;
    }

    def annexes(path: str) -> list[tuple[str, str]] {
        return [(self.read(candidate), candidate) for candidate in self.annex_paths(path)];
    }

    def set_overrides(sources: dict[str, str]) -> set[str] {
        current = {
            os.path.realpath(path): source for (path, source) in sources.items()
        };
        changed = {
            path
            for path in self.overrides.keys() | current.keys()
            if self.overrides.get(path) != current.get(path)
                and content_digest(
                    self.overrides[path].encode('utf-8')
                        if path in self.overrides else source_bytes(path)
                ) != content_digest(
                    current[path].encode('utf-8')
                        if path in current else source_bytes(path)
                )
        };
        self.overrides = current;
        return changed;
    }

    def clear {
        self.overrides.clear();
    }
}
