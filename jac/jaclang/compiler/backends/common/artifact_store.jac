import from weakref { WeakKeyDictionary, ReferenceType, ref }
import from contextvars { ContextVar }
import from contextlib { contextmanager }
import type from collections.abc { Iterator }
import type from jaclang.compiler.ir.base { UniNode }
import type from jaclang.compiler.backends.common.artifacts { NodeArtifacts }

obj ArtifactStore {
    has records: WeakKeyDictionary[UniNode, NodeArtifacts] = WeakKeyDictionary();

    def output(nd: UniNode) -> NodeArtifacts {
        import from jaclang.compiler.backends.common.artifacts { NodeArtifacts }
        record = self.records.get(nd);
        if record is None {
            record = NodeArtifacts();
            self.records[nd] = record;
        }
        _owners[nd] = ref(self);
        return record;
    }

    def discard(path: str) {
        for nd in list(self.records) {
            if nd.loc.mod_path == path {
                self.records.pop(nd, None);
                _owners.pop(nd, None);
            }
        }
    }

    def clear {
        for nd in list(self.records) {
            _owners.pop(nd, None);
        }
        self.records.clear();
    }
}

glob _owners: WeakKeyDictionary[UniNode, ReferenceType[ArtifactStore]] = WeakKeyDictionary(),
     _active_artifacts: ContextVar[ArtifactStore | None] = ContextVar(
         'jac_artifacts', `default=None
     );

@contextmanager
def artifact_scope(store: ArtifactStore) -> Iterator[None] {
    token = _active_artifacts.set(store);
    try {
        yield ;
    } finally {
        _active_artifacts.reset(token);
    }
}

def artifact_for(nd: UniNode) -> NodeArtifacts {
    owner = _owners.get(nd);
    store = owner() if owner is not None else None;
    store = store or _active_artifacts.get();
    if store is None {
        raise RuntimeError(
            'Backend output requires a compilation or tool request context'
        );
    }
    return store.output(nd);
}

def existing_artifact(nd: UniNode) -> NodeArtifacts | None {
    owner = _owners.get(nd);
    store = owner() if owner is not None else None;
    return store.records.get(nd) if store is not None else None;
}
