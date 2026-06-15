"""End-to-end tests for Firestore-backed kvstore against the Firebase Emulator.

Prerequisites:
  - firebase-tools installed (npm install -g firebase-tools)
  - JDK 21+ on PATH or JAVA_HOME
  - google-cloud-firestore installed (pip install jac-scale[firebase])

Run:
  export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
  firebase emulators:start --only firestore --project jac-e2e &
  export FIRESTORE_EMULATOR_HOST=localhost:8080
  jac test test_firestore_e2e.jac
"""

import os;
import subprocess;
import time;
import uuid;
import unittest;

import from jac_scale.db { Db }
import from jac_scale.factories.database_factory { DatabaseType }
import from jac_scale.lib { kvstore }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
"""Skip the calling test unless a Firestore emulator is configured.

These are wire-level integration tests, so without a running emulator there is
nothing to talk to and a real Firestore client would only fail on missing
credentials. Call at the top of any test that opens a Firestore connection.
"""
def _require_emulator {
    if not os.environ.get('FIRESTORE_EMULATOR_HOST') {
        raise unittest.SkipTest(
            'FIRESTORE_EMULATOR_HOST not set. Start the emulator: '
            'firebase emulators:start --only firestore --project jac-e2e'
        );
    }
}

"""Create a fresh kvstore Db pointing at the emulator (skips without one)."""
def _make_db -> Db {
    _require_emulator();
    return kvstore(db_name='e2e_test', db_type='firestore', uri='jac-e2e');
}

"""Generate a unique collection name to avoid test collisions."""
def _unique_col -> str {
    return f'test_{uuid.uuid4().hex[:8]}';
}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
test "firestore e2e: set, get, exists, delete lifecycle" {
    db = _make_db();
    col = _unique_col();

    # Set
    assert db.set('user:1', {'name': 'Alice', 'age': 30}, col) == 'user:1';

    # Get
    doc = db.get('user:1', col);
    assert doc is not None;
    assert doc['name'] == 'Alice';
    assert doc['age'] == 30;
    assert doc['_id'] == 'user:1';

    # Exists
    assert db.exists('user:1', col) is True;
    assert db.exists('user:999', col) is False;

    # Delete
    assert db.delete('user:1', col) == 1;
    assert db.get('user:1', col) is None;
    assert db.exists('user:1', col) is False;

    # Delete non-existent returns 0, matching MongoDb semantics.
    assert db.delete('user:1', col) == 0;
}


test "firestore e2e: insert_one, find_by_id, update_by_id, delete_by_id" {
    db = _make_db();
    col = _unique_col();

    # Insert
    result = db.insert_one(col, {'_id': 'doc1', 'title': 'Test', 'views': 0});
    assert result.inserted_id == 'doc1';

    # Find by ID
    doc = db.find_by_id(col, 'doc1');
    assert doc is not None;
    assert doc['title'] == 'Test';
    assert doc['_id'] == 'doc1';

    # Update by ID
    upd = db.update_by_id(col, 'doc1', {'$set': {'views': 42}});
    assert upd.modified_count == 1;

    updated = db.find_by_id(col, 'doc1');
    assert updated['views'] == 42;

    # Delete by ID
    deleted = db.delete_by_id(col, 'doc1');
    assert deleted.deleted_count == 1;
    assert db.find_by_id(col, 'doc1') is None;
    assert db.delete_by_id(col, 'doc1').deleted_count == 0;
}


test "firestore e2e: insert_many and find with filters" {
    db = _make_db();
    col = _unique_col();

    result = db.insert_many(
        col,
        [
            {'_id': 'apple', 'name': 'Apple', 'price': 1.20, 'category': 'fruit'},
            {'_id': 'banana', 'name': 'Banana', 'price': 0.50, 'category': 'fruit'},
            {'_id': 'carrot', 'name': 'Carrot', 'price': 0.80, 'category': 'vegetable'},
            {'_id': 'steak', 'name': 'Steak', 'price': 15.0, 'category': 'meat'}
        ]
    );
    assert len(result.inserted_ids) == 4;

    # Equality filter
    fruits = list(db.find(col, {'category': 'fruit'}));
    assert len(fruits) == 2;
    fruit_names = sorted([f['name'] for f in fruits]);
    assert fruit_names == ['Apple', 'Banana'];

    # Comparison filter ($gte)
    expensive = list(db.find(col, {'price': {'$gte': 1.0}}));
    assert len(expensive) == 2;
    expensive_names = sorted([e['name'] for e in expensive]);
    assert expensive_names == ['Apple', 'Steak'];

    # $in filter
    specific = list(db.find(col, {'name': {'$in': ['Apple', 'Carrot']}}));
    assert len(specific) == 2;

    # $and filter
    cheap_fruits = list(
        db.find(col, {'$and': [{'category': 'fruit'}, {'price': {'$lt': 1.0}}]})
    );
    assert len(cheap_fruits) == 1;
    assert cheap_fruits[0]['name'] == 'Banana';

    # find_one
    one = db.find_one(col, {'name': 'Carrot'});
    assert one is not None;
    assert one['category'] == 'vegetable';

    # Cleanup
    db.delete_many(col, {});
}


test "firestore e2e: update_one, update_many, upsert" {
    db = _make_db();
    col = _unique_col();

    db.insert_many(
        col,
        [
            {'_id': 'a', 'name': 'alpha', 'status': 'pending', 'priority': 1},
            {'_id': 'b', 'name': 'beta', 'status': 'pending', 'priority': 2},
            {'_id': 'c', 'name': 'gamma', 'status': 'done', 'priority': 3}
        ]
    );

    # update_one with field filter
    res = db.update_one(col, {'name': 'alpha'}, {'$set': {'status': 'processing'}});
    assert res.matched_count == 1;
    assert res.modified_count == 1;
    assert db.find_by_id(col, 'a')['status'] == 'processing';

    # update_many
    res = db.update_many(col, {'status': 'pending'}, {'$set': {'status': 'done'}});
    assert res.matched_count == 1;
    assert res.modified_count == 1;

    # upsert (document doesn't exist)
    res = db.update_one(
        col,
        {'name': 'delta'},
        {'$set': {'name': 'delta', 'status': 'new', 'priority': 0}},
        upsert_mode=True
    );
    assert res.upserted_id is not None;
    # Find the upserted document
    new_doc = db.find_one(col, {'name': 'delta'});
    assert new_doc is not None;
    assert new_doc['status'] == 'new';

    # upsert False (document doesn't exist)
    res = db.update_one(
        col, {'name': 'ghost'}, {'$set': {'status': 'ghost'}}, upsert_mode=False
    );
    assert res.matched_count == 0;
    assert res.modified_count == 0;
    assert db.find_one(col, {'name': 'ghost'}) is None;

    # Cleanup
    db.delete_many(col, {});
}


test "firestore e2e: delete_one and delete_many with filters" {
    db = _make_db();
    col = _unique_col();

    db.insert_many(
        col,
        [
            {'_id': 'x', 'tag': 'keep'},
            {'_id': 'y', 'tag': 'remove'},
            {'_id': 'z', 'tag': 'remove'}
        ]
    );

    # delete_one
    res = db.delete_one(col, {'tag': 'remove'});
    assert res.deleted_count == 1;

    # Only one 'remove' left
    remaining = list(db.find(col, {'tag': 'remove'}));
    assert len(remaining) == 1;

    # delete_many
    res = db.delete_many(col, {'tag': 'remove'});
    assert res.deleted_count == 1;

    # Only 'keep' remains
    all_docs = list(db.find(col, {}));
    assert len(all_docs) == 1;
    assert all_docs[0]['tag'] == 'keep';

    # Cleanup
    db.delete_many(col, {});
}


test "firestore e2e: overwrite with set, auto-generated ids" {
    db = _make_db();
    col = _unique_col();

    # set creates new document
    db.set('config', {'theme': 'dark', 'lang': 'en'}, col);
    doc = db.get('config', col);
    assert doc['theme'] == 'dark';

    # set overwrites existing document
    db.set('config', {'theme': 'light', 'font': 'sans'}, col);
    doc = db.get('config', col);
    assert doc['theme'] == 'light';
    assert doc.get('lang') is None;  # overwritten, not merged
    assert doc['font'] == 'sans';

    # insert_one auto-generates ID when _id is not provided
    res = db.insert_one(col, {'auto': True});
    assert res.inserted_id is not None;
    auto_doc = db.find_by_id(col, res.inserted_id);
    assert auto_doc is not None;
    assert auto_doc['auto'] is True;

    # Cleanup
    db.delete_many(col, {});
}


test "firestore e2e: collection namespacing across db_names" {
    _require_emulator();
    # Two kvstores with different db_names should have separate collections
    db1 = kvstore(db_name='app_one', db_type='firestore', uri='jac-e2e');
    db2 = kvstore(db_name='app_two', db_type='firestore', uri='jac-e2e');

    col = 'shared';
    db1.set('key1', {'source': 'app_one'}, col);
    db2.set('key1', {'source': 'app_two'}, col);

    doc1 = db1.get('key1', col);
    doc2 = db2.get('key1', col);

    assert doc1['source'] == 'app_one';
    assert doc2['source'] == 'app_two';

    # Cleanup
    db1.delete('key1', col);
    db2.delete('key1', col);
}
