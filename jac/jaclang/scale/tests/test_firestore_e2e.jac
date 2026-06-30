import os;
import subprocess;
import time;
import uuid;
import unittest;

import from jaclang.scale.persistence.db { Db }
import from jaclang.scale.deploy.database.factory { DatabaseType }
import from jaclang.scale.persistence.lib { kvstore }


def _require_emulator {
    if not os.environ.get('FIRESTORE_EMULATOR_HOST') {
        raise unittest.SkipTest(
            'FIRESTORE_EMULATOR_HOST not set. Start the emulator: '
            'firebase emulators:start --only firestore --project jac-e2e'
        );
    }
}

def _make_db -> Db {
    _require_emulator();
    return kvstore(db_name='e2e_test', db_type='firestore', uri='jac-e2e');
}

def _unique_col -> str {
    return f'test_{uuid.uuid4().hex[:8]}';
}


test "firestore e2e: set, get, exists, delete lifecycle" {
    db = _make_db();
    col = _unique_col();

    assert db.set('user:1', {'name': 'Alice', 'age': 30}, col) == 'user:1';

    doc = db.get('user:1', col);
    assert doc is not None;
    assert doc['name'] == 'Alice';
    assert doc['age'] == 30;
    assert doc['_id'] == 'user:1';

    assert db.exists('user:1', col) is True;
    assert db.exists('user:999', col) is False;

    assert db.delete('user:1', col) == 1;
    assert db.get('user:1', col) is None;
    assert db.exists('user:1', col) is False;

    assert db.delete('user:1', col) == 0;
}


test "firestore e2e: insert_one, find_by_id, update_by_id, delete_by_id" {
    db = _make_db();
    col = _unique_col();

    result = db.insert_one(col, {'_id': 'doc1', 'title': 'Test', 'views': 0});
    assert result.inserted_id == 'doc1';

    doc = db.find_by_id(col, 'doc1');
    assert doc is not None;
    assert doc['title'] == 'Test';
    assert doc['_id'] == 'doc1';

    upd = db.update_by_id(col, 'doc1', {'$set': {'views': 42}});
    assert upd.modified_count == 1;

    updated = db.find_by_id(col, 'doc1');
    assert updated['views'] == 42;

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

    fruits = list(db.find(col, {'category': 'fruit'}));
    assert len(fruits) == 2;
    fruit_names = sorted([f['name'] for f in fruits]);
    assert fruit_names == ['Apple', 'Banana'];

    expensive = list(db.find(col, {'price': {'$gte': 1.0}}));
    assert len(expensive) == 2;
    expensive_names = sorted([e['name'] for e in expensive]);
    assert expensive_names == ['Apple', 'Steak'];

    specific = list(db.find(col, {'name': {'$in': ['Apple', 'Carrot']}}));
    assert len(specific) == 2;

    cheap_fruits = list(
        db.find(col, {'$and': [{'category': 'fruit'}, {'price': {'$lt': 1.0}}]})
    );
    assert len(cheap_fruits) == 1;
    assert cheap_fruits[0]['name'] == 'Banana';

    one = db.find_one(col, {'name': 'Carrot'});
    assert one is not None;
    assert one['category'] == 'vegetable';

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

    res = db.update_one(col, {'name': 'alpha'}, {'$set': {'status': 'processing'}});
    assert res.matched_count == 1;
    assert res.modified_count == 1;
    assert db.find_by_id(col, 'a')['status'] == 'processing';

    res = db.update_many(col, {'status': 'pending'}, {'$set': {'status': 'done'}});
    assert res.matched_count == 1;
    assert res.modified_count == 1;

    res = db.update_one(
        col,
        {'name': 'delta'},
        {'$set': {'name': 'delta', 'status': 'new', 'priority': 0}},
        upsert_mode=True
    );
    assert res.upserted_id is not None;

    new_doc = db.find_one(col, {'name': 'delta'});
    assert new_doc is not None;
    assert new_doc['status'] == 'new';

    res = db.update_one(
        col, {'name': 'ghost'}, {'$set': {'status': 'ghost'}}, upsert_mode=False
    );
    assert res.matched_count == 0;
    assert res.modified_count == 0;
    assert db.find_one(col, {'name': 'ghost'}) is None;

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

    res = db.delete_one(col, {'tag': 'remove'});
    assert res.deleted_count == 1;

    remaining = list(db.find(col, {'tag': 'remove'}));
    assert len(remaining) == 1;

    res = db.delete_many(col, {'tag': 'remove'});
    assert res.deleted_count == 1;

    all_docs = list(db.find(col, {}));
    assert len(all_docs) == 1;
    assert all_docs[0]['tag'] == 'keep';

    db.delete_many(col, {});
}


test "firestore e2e: overwrite with set, auto-generated ids" {
    db = _make_db();
    col = _unique_col();

    db.set('config', {'theme': 'dark', 'lang': 'en'}, col);
    doc = db.get('config', col);
    assert doc['theme'] == 'dark';

    db.set('config', {'theme': 'light', 'font': 'sans'}, col);
    doc = db.get('config', col);
    assert doc['theme'] == 'light';
    assert doc.get('lang') is None;
    assert doc['font'] == 'sans';

    res = db.insert_one(col, {'auto': True});
    assert res.inserted_id is not None;
    auto_doc = db.find_by_id(col, res.inserted_id);
    assert auto_doc is not None;
    assert auto_doc['auto'] is True;

    db.delete_many(col, {});
}


test "firestore e2e: collection namespacing across db_names" {
    _require_emulator();

    db1 = kvstore(db_name='app_one', db_type='firestore', uri='jac-e2e');
    db2 = kvstore(db_name='app_two', db_type='firestore', uri='jac-e2e');

    col = 'shared';
    db1.set('key1', {'source': 'app_one'}, col);
    db2.set('key1', {'source': 'app_two'}, col);

    doc1 = db1.get('key1', col);
    doc2 = db2.get('key1', col);

    assert doc1['source'] == 'app_one';
    assert doc2['source'] == 'app_two';

    db1.delete('key1', col);
    db2.delete('key1', col);
}
