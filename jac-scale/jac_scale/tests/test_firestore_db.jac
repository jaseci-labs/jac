import os;
import unittest.mock;
import from jac_scale.config.config_loader { get_scale_config, reset_scale_config }
import from jac_scale.deploy.database.factory { DatabaseType, _resolve_uri }
import from jac_scale.persistence.firestore_db { FirestoreDb }
import from jac_scale.persistence.lib { kvstore }


def _copy_doc(doc: dict | None) -> dict | None {
    if doc is None {
        return None;
    }
    return doc.copy();
}


def _matches_filter(doc: dict, field_path: str, op_string: str, value: any) -> bool {
    doc_value = doc.get(field_path);

    if op_string == '==' {
        return doc_value == value;
    } elif op_string == '!=' {
        return doc_value != value;
    } elif op_string == '>' {
        return doc_value is not None and doc_value > value;
    } elif op_string == '>=' {
        return doc_value is not None and doc_value >= value;
    } elif op_string == '<' {
        return doc_value is not None and doc_value < value;
    } elif op_string == '<=' {
        return doc_value is not None and doc_value <= value;
    } elif op_string == 'in' {
        return doc_value in value;
    } elif op_string == 'not-in' {
        return doc_value not in value;
    }

    raise ValueError(f'Unsupported fake Firestore operator: {op_string}');
}


class _FakeAlreadyExists(Exception) {}


obj _FakeDocSnapshot {
    has id: str,
        data: dict | None = None,
        exists: bool = False;

    def postinit {
        self.exists = self.data is not None;
    }

    def to_dict -> dict | None {
        return _copy_doc(self.data);
    }
}


obj _FakeDocRef {
    has collection: _FakeCollection,
        id: str;

    def get -> _FakeDocSnapshot {
        return _FakeDocSnapshot(
            id=self.id, data=_copy_doc(self.collection.docs.get(self.id))
        );
    }

    def set(data: dict, merge: bool = False) {
        if merge and self.id in self.collection.docs {
            existing = _copy_doc(self.collection.docs[self.id]) or {};
            existing.update(data);
            self.collection.docs[self.id] = existing;
        } else {
            self.collection.docs[self.id] = _copy_doc(data) or {};
        }
    }

    def create(data: dict) {
        if self.id in self.collection.docs {
            raise _FakeAlreadyExists(f'Document {self.id} already exists');
        }
        self.set(data);
    }

    def update(data: dict) {
        if self.id not in self.collection.docs {
            raise KeyError(self.id);
        }
        existing = _copy_doc(self.collection.docs[self.id]) or {};
        existing.update(data);
        self.collection.docs[self.id] = existing;
    }

    def delete {
        self.collection.docs.pop(self.id, None);
    }
}


obj _FakeFieldFilter {
    has field_path: str,
        op_string: str,
        value: any;
}


obj _FakeCountSnapshot {
    has value: int;
}


obj _FakeAggregateQuery {
    has query: _FakeQuery;

    def get -> list {
        return [[_FakeCountSnapshot(value=len(self.query.stream()))]];
    }
}


obj _FakeQuery {
    has collection: _FakeCollection,
        filters: list = [],
        limit_count: int | None = None,
        select_fields: (list | None) = None;

    def where(
        field_path: str = '',
        op_string: str = '',
        value: any = None,
        filter: (_FakeFieldFilter | None) = None
    ) -> _FakeQuery {
        if filter is not None {
            actual_field = filter.field_path;
            actual_op = filter.op_string;
            actual_val = filter.value;
        } else {
            actual_field = field_path;
            actual_op = op_string;
            actual_val = value;
        }
        next_filters = self.filters + [
            {'field_path': actual_field, 'op_string': actual_op, 'value': actual_val}
        ];
        return _FakeQuery(
            collection=self.collection,
            filters=next_filters,
            limit_count=self.limit_count,
            select_fields=self.select_fields
        );
    }

    def limit(count: int) -> _FakeQuery {
        return _FakeQuery(
            collection=self.collection,
            filters=self.filters,
            limit_count=count,
            select_fields=self.select_fields
        );
    }

    def select(field_paths: list) -> _FakeQuery {
        return _FakeQuery(
            collection=self.collection,
            filters=self.filters,
            limit_count=self.limit_count,
            select_fields=list(field_paths)
        );
    }

    def count -> _FakeAggregateQuery {
        return _FakeAggregateQuery(query=self);
    }

    def stream -> list {
        results: list = [];
        for (doc_id, doc) in self.collection.docs.items() {
            matched = True;
            for current in self.filters {
                if not _matches_filter(
                    doc, current['field_path'], current['op_string'], current['value']
                ) {
                    matched = False;
                    break;
                }
            }
            if matched {
                data = _copy_doc(doc);
                if self.select_fields is not None and data is not None {
                    projected: dict = {};
                    for (k, v) in data.items() {
                        if k in self.select_fields {
                            projected[k] = v;
                        }
                    }
                    data = projected;
                }
                results.append(_FakeDocSnapshot(id=doc_id, data=data));
            }
        }
        if self.limit_count is not None {
            return results[:self.limit_count];
        }
        return results;
    }
}


obj _FakeCollection {
    has name: str,
        docs: dict[str, dict] = {};

    def document(doc_id: str) -> _FakeDocRef {
        return _FakeDocRef(collection=self, id=doc_id);
    }

    def where(
        field_path: str = '',
        op_string: str = '',
        value: any = None,
        filter: (_FakeFieldFilter | None) = None
    ) -> _FakeQuery {
        return _FakeQuery(collection=self).where(
            field_path=field_path, op_string=op_string, value=value, filter=filter
        );
    }

    def limit(count: int) -> _FakeQuery {
        return _FakeQuery(collection=self, limit_count=count);
    }

    def select(field_paths: list) -> _FakeQuery {
        return _FakeQuery(collection=self, select_fields=list(field_paths));
    }

    def stream -> list {
        return _FakeQuery(collection=self).stream();
    }

    def count -> _FakeAggregateQuery {
        return _FakeQuery(collection=self).count();
    }
}


obj _FakeBatch {
    has ops: list = [];

    def set(doc_ref: _FakeDocRef, data: dict) {
        self.ops.append({'kind': 'set', 'ref': doc_ref, 'data': _copy_doc(data) or {}});
    }

    def create(doc_ref: _FakeDocRef, data: dict) {
        self.ops.append(
            {'kind': 'create', 'ref': doc_ref, 'data': _copy_doc(data) or {}}
        );
    }

    def update(doc_ref: _FakeDocRef, data: dict) {
        self.ops.append(
            {'kind': 'update', 'ref': doc_ref, 'data': _copy_doc(data) or {}}
        );
    }

    def delete(doc_ref: _FakeDocRef) {
        self.ops.append({'kind': 'delete', 'ref': doc_ref});
    }

    def commit {
        pending_create_ids: set = set();
        for op in self.ops {
            if op['kind'] == 'create' {
                doc_id = op['ref'].id;
                if (
                    doc_id in pending_create_ids or doc_id in op['ref'].collection.docs
                ) {
                    raise _FakeAlreadyExists(f'Document {doc_id} already exists');
                }
                pending_create_ids.add(doc_id);
            }
        }
        for op in self.ops {
            if op['kind'] == 'set' {
                op['ref'].set(op['data']);
            } elif op['kind'] == 'create' {
                op['ref'].set(op['data']);
            } elif op['kind'] == 'update' {
                op['ref'].update(op['data']);
            } else {
                op['ref'].delete();
            }
        }
        self.ops = [];
    }
}


obj _FakeFirestoreClient {
    has collections: dict[str, _FakeCollection] = {};

    def collection(name: str) -> _FakeCollection {
        if name not in self.collections {
            self.collections[name] = _FakeCollection(name=name);
        }
        return self.collections[name];
    }

    def batch -> _FakeBatch {
        return _FakeBatch();
    }

    def close {
        return None;
    }
}


test "firestore kvstore operations" {
    client = _FakeFirestoreClient();
    db = FirestoreDb(client=client, db_name='app');

    assert db.set('session:1', {'user_id': '42'}, 'sessions') == 'session:1';
    assert db.get('session:1', 'sessions')['user_id'] == '42';
    assert db.get('session:1', 'sessions')['_id'] == 'session:1';
    assert db.exists('session:1', 'sessions') is True;
    assert db.delete('session:1', 'sessions') == 1;
    assert db.get('session:1', 'sessions') is None;
    assert db.delete('session:1', 'sessions') == 0;

    alice = db.insert_one('users', {'name': 'Alice', 'role': 'admin'});
    bob = db.insert_one('users', {'name': 'Bob', 'role': 'user', 'age': 25});
    batch = db.insert_many(
        'users',
        [
            {'name': 'Carol', 'role': 'admin', 'age': 31},
            {'name': 'Dan', 'role': 'user', 'age': 19}
        ]
    );

    assert alice.inserted_id is not None;
    assert bob.inserted_id is not None;
    assert len(batch.inserted_ids) == 2;
    assert 'app__users' in client.collections;

    admins = list(db.find('users', {'role': 'admin'}));
    assert len(admins) == 2;
    assert db.find_one('users', {'name': 'Alice'})['role'] == 'admin';
    assert len(list(db.find('users', {'age': {'$gte': 25}}))) == 2;
    assert db.count_documents('users', {}) == 4;
    assert db.count_documents('users', {'role': 'admin'}) == 2;
    assert db.count_documents('users', {'name': 'Bob'}) == 1;
    assert db.count_documents('users', {'name': 'Missing'}) == 0;

    assert db.update_one(
        'users', {'name': 'Alice'}, {'$set': {'status': 'active'}}
    ).modified_count == 1;
    assert db.find_one('users', {'name': 'Alice'})['status'] == 'active';

    assert (
        db.update_many(
            'users', {'role': 'admin'}, {'$set': {'tier': 'gold'}}
        ).modified_count == 2
    );
    assert len(list(db.find('users', {'tier': 'gold'}))) == 2;

    assert db.delete_one('users', {'name': 'Bob'}).deleted_count == 1;
    assert db.find_one('users', {'name': 'Bob'}) is None;
    assert db.delete_many('users', {'tier': 'gold'}).deleted_count == 2;
    assert len(list(db.find('users', {'role': 'admin'}))) == 0;

    profile = db.insert_one('profiles', {'name': 'Dora'});
    assert db.update_by_id(
        'profiles', profile.inserted_id, {'$set': {'status': 'active'}}
    ).modified_count == 1;
    assert db.find_by_id('profiles', profile.inserted_id)['status'] == 'active';
    assert db.delete_by_id('profiles', profile.inserted_id).deleted_count == 1;
    assert db.find_by_id('profiles', profile.inserted_id) is None;
    assert db.delete_by_id('profiles', profile.inserted_id).deleted_count == 0;
}


test "firestore insert_one rejects duplicate explicit _id" {
    client = _FakeFirestoreClient();
    db = FirestoreDb(client=client, db_name='app');

    db.insert_one('users', {'_id': 'u1', 'name': 'Alice'});
    raised = False;
    try {
        db.insert_one('users', {'_id': 'u1', 'name': 'Eve'});
    } except _FakeAlreadyExists {
        raised = True;
    }
    assert raised;
    assert db.find_by_id('users', 'u1')['name'] == 'Alice';
}


test "firestore insert_many rejects duplicate explicit _id" {
    client = _FakeFirestoreClient();
    db = FirestoreDb(client=client, db_name='app');

    db.insert_one('users', {'_id': 'u1', 'name': 'Alice'});
    raised = False;
    try {
        db.insert_many(
            'users', [{'_id': 'u2', 'name': 'Bob'}, {'_id': 'u1', 'name': 'Eve'}]
        );
    } except _FakeAlreadyExists {
        raised = True;
    }
    assert raised;
    assert db.find_by_id('users', 'u1')['name'] == 'Alice';
    assert db.find_by_id('users', 'u2') is None;
}


test "firestore find honors projection" {
    client = _FakeFirestoreClient();
    db = FirestoreDb(client=client, db_name='app');

    db.insert_one('users', {'_id': 'u1', 'name': 'Alice', 'role': 'admin', 'age': 30});
    db.insert_one('users', {'_id': 'u2', 'name': 'Bob', 'role': 'user', 'age': 25});

    assert db.find_one('users', {'name': 'Alice'}, {'name': 1}) == {
        'name': 'Alice',
        '_id': 'u1'
    };

    assert db.find_one('users', {'name': 'Alice'}, {'name': 1, '_id': 0}) == {
        'name': 'Alice'
    };

    assert db.find_one('users', {'name': 'Bob'}, {'age': 0, 'role': 0}) == {
        'name': 'Bob',
        '_id': 'u2'
    };

    rows = list(db.find('users', {}, {'role': 1, '_id': 0}));
    assert sorted([r['role'] for r in rows]) == ['admin', 'user'];
    for r in rows {
        assert set(r.keys()) == {'role'};
    }

    raised = False;
    try {
        db.find('users', {}, {'name': 1, 'age': 0});
    } except ValueError {
        raised = True;
    }
    assert raised , 'Expected ValueError when mixing include and exclude';
}


test "kvstore routes firestore through pooled client helper" {
    fake_client = _FakeFirestoreClient();

    with unittest.mock.patch(
        'jac_scale.persistence.db.get_firestore_client', return_value=fake_client
    ) {
        db = kvstore(db_name='app', db_type='firestore');
        assert db.db_type == DatabaseType.FIRESTORE;
        assert db.set('hello', {'value': 1}) == 'hello';
        assert db.get('hello')['value'] == 1;
    }
}


test "firestore returns None for redis-only methods and graph persistence" {
    db = FirestoreDb(client=_FakeFirestoreClient(), db_name='app');

    assert db.set_with_ttl('key', {'v': 1}, ttl=60) is None;
    assert db.incr('counter') is None;
    assert db.find_nodes('TestNode') is None;
}


test "firestore rejects $or filter with NotImplementedError" {
    client = _FakeFirestoreClient();
    db = FirestoreDb(client=client, db_name='app');
    db.insert_one('items', {'status': 'a'});
    db.insert_one('items', {'status': 'b'});

    raised = False;
    try {
        db.find('items', {'$or': [{'status': 'a'}, {'status': 'b'}]});
    } except NotImplementedError {
        raised = True;
    }
    assert raised , 'Expected NotImplementedError for $or filter';
}


test "firestore rejects unsupported filter operator with ValueError" {
    client = _FakeFirestoreClient();
    db = FirestoreDb(client=client, db_name='app');
    db.insert_one('items', {'count': 5});

    raised = False;
    try {
        db.find('items', {'count': {'$exists': True}});
    } except ValueError {
        raised = True;
    }
    assert raised , 'Expected ValueError for unsupported operator $exists';
}


test "firestore config fallback" {
    old_project_id = os.environ.get('FIRESTORE_PROJECT_ID');

    os.environ['FIRESTORE_PROJECT_ID'] = 'firebase-project';
    reset_scale_config();

    try {
        db_config = get_scale_config().get_database_config();
        assert db_config['project_id'] == 'firebase-project';
        assert _resolve_uri(None, DatabaseType.FIRESTORE) == 'firebase-project';
        assert _resolve_uri('explicit-project', DatabaseType.FIRESTORE) == 'explicit-project';
    } finally {
        if old_project_id is None {
            os.environ.pop('FIRESTORE_PROJECT_ID', None);
        } else {
            os.environ['FIRESTORE_PROJECT_ID'] = old_project_id;
        }
        reset_scale_config();
    }
}
