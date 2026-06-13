"""Unit tests for Firestore-backed kvstore behavior."""

import os;
import unittest.mock;
import from jac_scale.config_loader { get_scale_config, reset_scale_config }
import from jac_scale.db { Db }
import from jac_scale.factories.database_factory { DatabaseType, _resolve_uri }
import from jac_scale.lib { kvstore }


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


obj _FakeQuery {
    has collection: _FakeCollection,
        filters: list = [],
        limit_count: int | None = None;

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
            limit_count=self.limit_count
        );
    }

    def limit(count: int) -> _FakeQuery {
        return _FakeQuery(
            collection=self.collection, filters=self.filters, limit_count=count
        );
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
                results.append(_FakeDocSnapshot(id=doc_id, data=_copy_doc(doc)));
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

    def stream -> list {
        return _FakeQuery(collection=self).stream();
    }
}


obj _FakeBatch {
    has ops: list = [];

    def set(doc_ref: _FakeDocRef, data: dict) {
        self.ops.append({'kind': 'set', 'ref': doc_ref, 'data': _copy_doc(data) or {}});
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
        for op in self.ops {
            if op['kind'] == 'set' {
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
    db = Db(client=client, db_name='app', db_type=DatabaseType.FIRESTORE);

    assert db.set('session:1', {'user_id': '42'}, 'sessions') == 'session:1';
    assert db.get('session:1', 'sessions')['user_id'] == '42';
    assert db.get('session:1', 'sessions')['_id'] == 'session:1';
    assert db.exists('session:1', 'sessions') is True;
    assert db.delete('session:1', 'sessions') == 1;
    assert db.get('session:1', 'sessions') is None;

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
}


test "kvstore routes firestore through pooled client helper" {
    fake_client = _FakeFirestoreClient();

    with unittest.mock.patch(
        'jac_scale.db.get_firestore_client', return_value=fake_client
    ) {
        db = kvstore(db_name='app', db_type='firestore');
        assert db.db_type == DatabaseType.FIRESTORE;
        assert db.set('hello', {'value': 1}) == 'hello';
        assert db.get('hello')['value'] == 1;
    }
}


test "firestore rejects redis methods and graph persistence" {
    db = Db(
        client=_FakeFirestoreClient(), db_name='app', db_type=DatabaseType.FIRESTORE
    );

    raised = False;
    try {
        db.set_with_ttl('key', {'v': 1}, ttl=60);
    } except NotImplementedError {
        raised = True;
    }
    assert raised , 'Expected NotImplementedError for set_with_ttl on firestore';

    raised = False;
    try {
        db.incr('counter');
    } except NotImplementedError {
        raised = True;
    }
    assert raised , 'Expected NotImplementedError for incr on firestore';

    raised = False;
    try {
        db.find_nodes('TestNode');
    } except NotImplementedError {
        raised = True;
    }
    assert raised , 'Expected NotImplementedError for find_nodes on firestore';
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
