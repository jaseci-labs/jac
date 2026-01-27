"""Implementation of program snapshot for non-blocking LSP queries."""

import threading;
import pickle;
import time;
import sys;
import from typing { Optional, Any, Callable }

"""Internal debug logging for snapshot."""
def _snap_debug(msg: str) -> None {
    print(f"[Snapshot] {msg}", file=sys.stderr);
}

impl ProgramSnapshot.postinit -> None {
    if self.timestamp == 0 {
        self.timestamp = time.time();
    }
}

impl ProgramSnapshot.get_module(path: str) -> Optional[Any] {
    return self.hub.get(path, None);
}

impl ProgramSnapshot.get_semantic_manager(path: str) -> Optional[Any] {
    return self.sem_managers.get(path, None);
}

impl ProgramSnapshot.get_diagnostics(path: str) -> list {
    diagnostics = [];
    for error in self.errors {
        if error?.loc and error.loc and error.loc?.mod_path {
            if error.loc.mod_path == path {
                diagnostics.append(error);
            }
        }
    }
    for warning in self.warnings {
        if warning?.loc and warning.loc and warning.loc?.mod_path {
            if warning.loc.mod_path == path {
                diagnostics.append(warning);
            }
        }
    }
    return diagnostics;
}

impl ProgramSnapshot.get_all_errors -> list {
    return self.errors;
}

impl ProgramSnapshot.get_all_warnings -> list {
    return self.warnings;
}

impl ProgramSnapshot.is_empty -> bool {
    return len(self.hub) == 0;
}

impl ProgramSnapshot.serialize -> bytes {
    _snap_debug(f"Serializing snapshot v{self.version}: {len(self.hub)} files, {len(self.errors)} errors");
    data = {
        'hub': self.hub,
        'sem_managers': {},  # Don't serialize sem_managers (not picklable)
        'errors': self.errors,
        'warnings': self.warnings,
        'version': self.version,
        'timestamp': self.timestamp
    };
    # AST nodes have deep parent-child relationships that can exceed default recursion limit.
    # Temporarily increase it for pickling.
    old_limit = sys.getrecursionlimit();
    try {
        sys.setrecursionlimit(max(old_limit, 50000));
        result = pickle.dumps(data);
        _snap_debug(f"Serialized snapshot: {len(result)} bytes");
        return result;
    } finally {
        sys.setrecursionlimit(old_limit);
    }
}

impl ProgramSnapshot.deserialize(data: bytes) -> ProgramSnapshot {
    _snap_debug(f"Deserializing snapshot: {len(data)} bytes");
    d = pickle.loads(data);
    snapshot = ProgramSnapshot(
        hub=d.get('hub', {}),
        sem_managers=d.get('sem_managers', {}),
        errors=d.get('errors', []),
        warnings=d.get('warnings', []),
        version=d.get('version', 0),
        timestamp=d.get('timestamp', time.time())
    );
    _snap_debug(f"Deserialized snapshot v{snapshot.version}: {len(snapshot.hub)} files");
    return snapshot;
}

impl ProgramSnapshot.from_program_state(
    hub: dict, sem_managers: dict, errors: list, warnings: list, version: int = 0
) -> ProgramSnapshot {
    return ProgramSnapshot(
        hub=hub,
        sem_managers=sem_managers,
        errors=errors,
        warnings=warnings,
        version=version,
        timestamp=time.time()
    );
}

impl SnapshotManager.postinit -> None {
    self._lock = threading.Lock();
    self._version_counter = 0;
    self._update_callbacks = [];
}

impl SnapshotManager.get_snapshot -> Optional[ProgramSnapshot] {
    with self._lock {
        return self._snapshot;
    }
}

impl SnapshotManager.update_snapshot(new_snapshot: ProgramSnapshot) -> None {
    _snap_debug(f"Updating to snapshot v{new_snapshot.version}");
    callbacks_to_run = [];
    with self._lock {
        self._snapshot = new_snapshot;
        self._version_counter = new_snapshot.version;
        callbacks_to_run = list(self._update_callbacks);
    }
    _snap_debug(f"Running {len(callbacks_to_run)} update callbacks");
    # Run callbacks outside lock
    for callback in callbacks_to_run {
        try {
            callback(new_snapshot);
        } except Exception as e {
            _snap_debug(f"Snapshot update callback error: {e}");
            print(f"Snapshot update callback error: {e}");
        }
    }
}

impl SnapshotManager.initialize_empty -> None {
    empty = create_empty_snapshot();
    self.update_snapshot(empty);
}

impl SnapshotManager.create_snapshot_from_program(
    hub: dict, sem_managers: dict, errors: list, warnings: list
) -> ProgramSnapshot {
    with self._lock {
        self._version_counter += 1;
        version = self._version_counter;
    }
    _snap_debug(f"Creating snapshot v{version}: {len(hub) if hub else 0} files, {len(errors) if errors else 0} errors");
    return ProgramSnapshot(
        hub=hub.copy() if hub else {},
        sem_managers=sem_managers.copy() if sem_managers else {},
        errors=list(errors) if errors else [],
        warnings=list(warnings) if warnings else [],
        version=version,
        timestamp=time.time()
    );
}

impl SnapshotManager.get_version -> int {
    with self._lock {
        if self._snapshot {
            return self._snapshot.version;
        }
        return 0;
    }
}

impl SnapshotManager.has_snapshot -> bool {
    with self._lock {
        return self._snapshot is not None;
    }
}

impl SnapshotManager.on_update(callback: Callable) -> None {
    with self._lock {
        self._update_callbacks.append(callback);
    }
}

impl create_empty_snapshot -> ProgramSnapshot {
    return ProgramSnapshot(
        hub={},
        sem_managers={},
        errors=[],
        warnings=[],
        version=0,
        timestamp=time.time()
    );
}
