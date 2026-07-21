import os;
import atexit;
import unittest.mock;
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.scale.deploy.database.factory { DatabaseType, _resolve_uri }
import from jaclang.scale.persistence.firestore_db { FirestoreDb }
import from jaclang.scale.persistence.lib { kvstore }
import from jaclang.scale._optdeps.pymongo { DuplicateKeyError }


glob _EMULATOR_IMAGE: str = 'gcr.io/google.com/cloudsdktool/google-cloud-cli',
     _EMULATOR_STATE: dict = {};


def _ensure_emulator -> dict {
    # Start a real Firestore emulator once, or raise SkipTest if unavailable.
    if _EMULATOR_STATE.get('started') {
        if _EMULATOR_STATE.get('error') is not None {
            raise unittest.SkipTest(_EMULATOR_STATE['error']);
        }
        return _EMULATOR_STATE;
    }
    _EMULATOR_STATE['started'] = True;

    try {
        import from testcontainers.core.container { DockerContainer }
        import from testcontainers.core.waiting_utils { wait_for_logs }
    } except ImportError as import_error {
        _EMULATOR_STATE['error'] = f'testcontainers is not installed: {import_error}';
        raise unittest.SkipTest(_EMULATOR_STATE['error']);
    }

    container = (
        DockerContainer(_EMULATOR_IMAGE).with_command(
            'gcloud emulators firestore start '
            '--host-port=0.0.0.0:8080 --project=test'
        ).with_exposed_ports(
            8080
        )
    );

    try {
        container.start();
        wait_for_logs(container, 'running', timeout=180);
    } except Exception as start_error {
        try {
            container.stop();
        } except Exception { }
        _EMULATOR_STATE['error'] = (
            f'Firestore emulator ({_EMULATOR_IMAGE}) could not start - '
            f'Docker or the emulator image is unavailable in this environment: '
            f'{start_error}'
        );
        raise unittest.SkipTest(_EMULATOR_STATE['error']);
    }

    atexit.register(container.stop);

    host = container.get_container_host_ip();
    port = container.get_exposed_port(8080);
    _EMULATOR_STATE['container'] = container;
    _EMULATOR_STATE['host_port'] = f'{host}:{port}';
    return _EMULATOR_STATE;
}


def _make_client -> any {
    # Build a real google.cloud.firestore client bound to the emulator.
    state = _ensure_emulator();
    os.environ['FIRESTORE_EMULATOR_HOST'] = state['host_port'];
    os.environ['GOOGLE_CLOUD_PROJECT'] = 'test';
    import from google.cloud.firestore { Client }
    return Client(project='test');
}


def _make_db(db_name: str) -> FirestoreDb {
    # Fresh FirestoreDb over the real emulator; unique db_name isolates data.
    return FirestoreDb(client=_make_client(), db_name=db_name);
}


test "firestore kvstore operations" {
    db = _make_db('appcrud');

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

    # Real backend must hold the documents under the db-prefixed collection name.
    collection_ids = [ref.id for ref in db.client.collections()];
    assert 'appcrud__users' in collection_ids;
    assert len(list(db.client.collection('appcrud__users').stream())) == 4;

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
    db = _make_db('dupone');

    db.insert_one('users', {'_id': 'u1', 'name': 'Alice'});
    raised = False;
    try {
        db.insert_one('users', {'_id': 'u1', 'name': 'Eve'});
    } except DuplicateKeyError {
        raised = True;
    }
    assert raised;
    assert db.find_by_id('users', 'u1')['name'] == 'Alice';
}


test "firestore insert_many rejects duplicate explicit _id" {
    db = _make_db('dupmany');

    db.insert_one('users', {'_id': 'u1', 'name': 'Alice'});
    raised = False;
    try {
        db.insert_many(
            'users', [{'_id': 'u2', 'name': 'Bob'}, {'_id': 'u1', 'name': 'Eve'}]
        );
    } except DuplicateKeyError {
        raised = True;
    }
    assert raised;
    assert db.find_by_id('users', 'u1')['name'] == 'Alice';
    # The batch is atomic - the non-conflicting sibling must not be written.
    assert db.find_by_id('users', 'u2') is None;
}


test "firestore find honors projection" {
    db = _make_db('projection');

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
    real_client = _make_client();

    with unittest.mock.patch(
        'jaclang.scale.persistence.db.get_firestore_client', return_value=real_client
    ) {
        db = kvstore(db_name='routing', db_type='firestore');
        assert db.db_type == DatabaseType.FIRESTORE;
        assert db.set('hello', {'value': 1}) == 'hello';
        assert db.get('hello')['value'] == 1;
    }
}


test "firestore returns None for redis-only methods and graph persistence" {
    db = _make_db('redisonly');

    assert db.set_with_ttl('key', {'v': 1}, ttl=60) is None;
    assert db.incr('counter') is None;
    assert db.find_nodes('TestNode') is None;
}


test "firestore rejects $or filter with NotImplementedError" {
    db = _make_db('orfilter');
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
    db = _make_db('badoperator');
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
