glob PLACEMENT_SCHEMA: int = 1;
import json;
import from jaclang.runtime.object_model { field }


obj ElementSummary {
    has index: int = -1,
        kind: str = '',
        name: str = '',
        pinned: str = '',
        is_pub: bool = False,
        sv_import: bool = False,
        import_eco: str = '',
        import_jac_target: str = '',
        import_items: list[str] = field(default_factory=`list),
        import_py_targets: list[str] = field(default_factory=`list),
        reqs: list = field(default_factory=`list),
        refs: list[int] = field(default_factory=`list),
        escapes: list = field(default_factory=`list),
        glob_writes: list[int] = field(default_factory=`list);

    def to_dict -> dict {
        return {
            'index': self.index,
            'kind': self.kind,
            'name': self.name,
            'pinned': self.pinned,
            'is_pub': self.is_pub,
            'sv_import': self.sv_import,
            'import_eco': self.import_eco,
            'import_jac_target': self.import_jac_target,
            'import_items': list(self.import_items),
            'import_py_targets': list(self.import_py_targets),
            'reqs': [list(r) for r in self.reqs],
            'refs': list(self.refs),
            'escapes': [list(e) for e in self.escapes],
            'glob_writes': list(self.glob_writes)
        };
    }

    static def from_dict(d: dict) -> ElementSummary {
        es = ElementSummary();
        es.index = int(d.get('index', -1));
        es.kind = str(d.get('kind', ''));
        es.name = str(d.get('name', ''));
        es.pinned = str(d.get('pinned', ''));
        es.is_pub = bool(d.get('is_pub', False));
        es.sv_import = bool(d.get('sv_import', False));
        es.import_eco = str(d.get('import_eco', ''));
        es.import_jac_target = str(d.get('import_jac_target', ''));
        es.import_items = [str(x) for x in d.get('import_items', [])];
        es.import_py_targets = [str(x) for x in d.get('import_py_targets', [])];
        es.reqs = [list(r) for r in d.get('reqs', [])];
        es.refs = [int(x) for x in d.get('refs', [])];
        es.escapes = [list(e) for e in d.get('escapes', [])];
        es.glob_writes = [int(x) for x in d.get('glob_writes', [])];
        return es;
    }
}

obj PlacementSummary {
    has schema: int = 1,
        mod_path: str = '',
        decided: str = '',
        anchors: list[str] = field(default_factory=`list),
        native_blocker: str = '',
        jac_deps: list[str] = field(default_factory=`list),
        has_refs: bool = False,
        elements: list[ElementSummary] = field(default_factory=`list);

    def to_dict -> dict {
        return {
            'schema': self.schema,
            'mod_path': self.mod_path,
            'decided': self.decided,
            'anchors': list(self.anchors),
            'native_blocker': self.native_blocker,
            'jac_deps': list(self.jac_deps),
            'has_refs': self.has_refs,
            'elements': [e.to_dict() for e in self.elements]
        };
    }

    static def from_dict(d: dict) -> (PlacementSummary | None) {
        if not isinstance(d, dict) or d.get('schema') != PLACEMENT_SCHEMA {
            return None;
        }
        ps = PlacementSummary();
        ps.mod_path = str(d.get('mod_path', ''));
        ps.decided = str(d.get('decided', ''));
        ps.anchors = [str(x) for x in d.get('anchors', [])];
        ps.native_blocker = str(d.get('native_blocker', ''));
        ps.jac_deps = [str(x) for x in d.get('jac_deps', [])];
        ps.has_refs = bool(d.get('has_refs', False));
        ps.elements = [
            ElementSummary.from_dict(e)
            for e in d.get('elements', [])
            if isinstance(e, dict)
        ];
        return ps;
    }
}

def summary_to_bytes(ps: PlacementSummary) -> bytes {
    return json.dumps(ps.to_dict()).encode('utf-8');
}

def summary_from_bytes(data: bytes) -> (PlacementSummary | None) {
    try {
        parsed = json.loads(data.decode('utf-8'));
        if not isinstance(parsed, dict) {
            return None;
        }
        return PlacementSummary.from_dict(parsed);
    } except Exception {
        return None;
    }
}
