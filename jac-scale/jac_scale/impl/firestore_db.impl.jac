"""Firestore implementation for FirestoreDb."""
import from uuid { uuid4 }
import from jac_scale._db_helpers { _validate_not_read_only }

# ===== FIRESTORE HELPERS =====

"""Generate Firestore collection name with db namespace."""
def _firestore_collection_name(db_name: str, col_name: str) -> str {
    return f"{db_name}__{col_name}";
}

"""Convert a Firestore document snapshot to a plain dict (with _id injected)."""
def _firestore_snapshot_to_doc(snapshot: any) -> dict | None {
    if not snapshot.exists {
        return None;
    }
    doc = snapshot.to_dict();
    doc['_id'] = snapshot.id;
    return doc;
}

"""Extract document ID from a document dict (_id field or None)."""
def _firestore_document_id(document: dict) -> str | None {
    return document.get('_id') or document.get('id');
}

"""Return a copy of a document dict without the _id field (Firestore stores ID in metadata)."""
def _firestore_document_body(document: dict) -> dict {
    body = document.copy();
    body.pop('_id', None);
    body.pop('id', None);
    return body;
}

"""Resolve the fields to write from a MongoDB-style update_data dict.

Supports `$set` operator (merges the sub-dict) or plain dict (replaces entire doc).
"""
def _firestore_update_fields(update_data: dict) -> dict {
    if '$set' in update_data {
        fields = {};
        for (k, v) in update_data['$set'].items() {
            fields[k] = v;
        }
        # Handle other operators by merging them in
        for (op, sub) in update_data.items() {
            if op.startswith('$') and op != '$set' {
                if isinstance(sub, dict) {
                    for (k, v) in sub.items() {
                        fields[k] = v;
                    }
                }
            }
        }
        return fields;
    }
    return update_data;
}

"""Apply a single field filter to a Firestore query.

Translates MongoDB-style operators ($gt, $gte, $lt, $lte, $ne, $in, $nin)
to Firestore where() calls."""
def _apply_firestore_field_filter(
    query: any, field_name: str, field_value: any
) -> any {
    if isinstance(field_value, dict) {
        for (op, val) in field_value.items() {
            query = _apply_firestore_field_value(query, field_name, op, val);
        }
    } else {
        query = query.where(filter=FieldFilter(field_name, '==', field_value));
    }
    return query;
}

"""Map a single MongoDB operator to a Firestore FieldFilter."""
def _apply_firestore_field_value(
    query: any, field_name: str, op: str, val: any
) -> any {
    import from google.cloud.firestore_v1 { FieldFilter }
    op_map = {
        '$gt': '>',
        '$gte': '>=',
        '$lt': '<',
        '$lte': '<=',
        '$ne': '!=',
        '$in': 'in',
        '$nin': 'not-in'
    };
    if op in op_map {
        return query.where(filter=FieldFilter(field_name, op_map[op], val));
    }
    return query;
}

"""Apply a MongoDB-style filter dict to a Firestore query."""
def _apply_firestore_filters(query: any, filter: dict) -> any {
    import from google.cloud.firestore_v1 { FieldFilter }
    current_query = query;
    for (field_name, field_value) in filter.items() {
        if isinstance(field_value, dict) {
            for (op, val) in field_value.items() {
                op_map = {
                    '$gt': '>',
                    '$gte': '>=',
                    '$lt': '<',
                    '$lte': '<=',
                    '$ne': '!=',
                    '$in': 'in',
                    '$nin': 'not-in'
                };
                if op in op_map {
                    current_query = current_query.where(
                        filter=FieldFilter(field_name, op_map[op], val)
                    );
                }
            }
        } else {
            current_query = current_query.where(
                filter=FieldFilter(field_name, '==', field_value)
            );
        }
    }
    return current_query;
}

"""Commit current batch and return a fresh one if BATCH_LIMIT writes are pending."""
def _firestore_batch_after_write(
    client: any, batch: any, pending: int
) -> tuple {
    BATCH_LIMIT = 499;
    pending += 1;
    if pending >= BATCH_LIMIT {
        batch.commit();
        return (client.batch(), 0);
    }
    return (batch, pending);
}

"""Commit the final batch if there are any pending writes."""
def _firestore_batch_finalize(batch: any, pending: int) {
    if pending > 0 {
        batch.commit();
    }
}

"""Build a seed document from a filter + update_data for upsert operations."""
def _firestore_seed_document(filter: dict, update_data: dict) -> dict {
    seed = {};
    for (k, v) in filter.items() {
        if not k.startswith('$') {
            seed[k] = v;
        }
    }
    update_fields = _firestore_update_fields(update_data);
    seed.update(update_fields);
    return seed;
}


# ===== FIRESTORE_DB IMPLEMENTATIONS =====

impl FirestoreDb._get_firestore_collection(col_name: str) -> any {
    return self.client.collection(
        _firestore_collection_name(self.db_name, col_name)
    );
}

impl FirestoreDb.get(key: str, col_name: str = 'default') -> dict | None {
    snapshot = self._get_firestore_collection(col_name).document(key).get();
    return _firestore_snapshot_to_doc(snapshot);
}

impl FirestoreDb.set(key: str, value: dict, col_name: str = 'default') -> str {
    _validate_not_read_only(col_name);
    doc_ref = self._get_firestore_collection(col_name).document(key);
    doc_ref.set(_firestore_document_body(value));
    return key;
}

impl FirestoreDb.delete(key: str, col_name: str = 'default') -> int {
    _validate_not_read_only(col_name);
    # Firestore delete() is a no-op when the document doesn't exist (no error
    # thrown), so we skip the pre-read and return 1 optimistically.  This
    # saves one billed read per call.  Callers that need an exact count
    # should call exists() first.
    doc_ref = self._get_firestore_collection(col_name).document(key);
    doc_ref.delete();
    return 1;
}

impl FirestoreDb.exists(key: str, col_name: str = 'default') -> bool {
    return self._get_firestore_collection(col_name).document(key).get().exists;
}

impl FirestoreDb.find_one(
    col_name: str, filter: dict, projection: dict | None = None
) -> dict | None {
    query = _apply_firestore_filters(
        self._get_firestore_collection(col_name), filter
    );
    results = list(query.limit(1).stream());
    return _firestore_snapshot_to_doc(results[0]) if results else None;
}

impl FirestoreDb.find(
    col_name: str,
    filter: dict,
    projection: dict | None = None,
    limit: int | None = None
) -> list {
    query = _apply_firestore_filters(
        self._get_firestore_collection(col_name), filter
    );
    if limit is not None {
        query = query.limit(limit);
    }
    results: list = [];
    for snapshot in query.stream() {
        if (doc := _firestore_snapshot_to_doc(snapshot)) is not None {
            results.append(doc);
        }
    }
    return results;
}

impl FirestoreDb.insert_one(
    col_name: str, document: dict
) -> InsertResult {
    _validate_not_read_only(col_name);
    doc_id = _firestore_document_id(document) or str(uuid4());
    self._get_firestore_collection(col_name).document(doc_id).set(
        _firestore_document_body(document)
    );
    return InsertResult(inserted_id=doc_id);
}

impl FirestoreDb.update_one(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> UpdateResult {
    _validate_not_read_only(col_name);
    query = _apply_firestore_filters(
        self._get_firestore_collection(col_name), filter
    );
    results = list(query.limit(1).stream());
    update_fields = _firestore_update_fields(update_data);

    if not results {
        if not upsert_mode {
            return UpdateResult(matched_count=0, modified_count=0);
        }
        seed_document = _firestore_seed_document(filter, update_data);
        doc_id = _firestore_document_id(seed_document) or str(uuid4());
        self._get_firestore_collection(col_name).document(doc_id).set(
            _firestore_document_body(seed_document), merge=True
        );
        return UpdateResult(matched_count=0, modified_count=0, upserted_id=doc_id);
    }

    self._get_firestore_collection(col_name).document(results[0].id).update(
        update_fields
    );
    return UpdateResult(matched_count=1, modified_count=1);
}

impl FirestoreDb.delete_one(
    col_name: str, filter: dict
) -> DeleteResult {
    _validate_not_read_only(col_name);
    query = _apply_firestore_filters(
        self._get_firestore_collection(col_name), filter
    );
    results = list(query.limit(1).stream());
    if not results {
        return DeleteResult(deleted_count=0);
    }
    self._get_firestore_collection(col_name).document(results[0].id).delete();
    return DeleteResult(deleted_count=1);
}

impl FirestoreDb.insert_many(
    col_name: str, documents: list
) -> InsertManyResult {
    _validate_not_read_only(col_name);
    inserted_ids: list = [];
    batch = self.client.batch();
    pending = 0;

    for document in documents {
        doc_id = _firestore_document_id(document) or str(uuid4());
        inserted_ids.append(doc_id);
        batch.set(
            self._get_firestore_collection(col_name).document(doc_id),
            _firestore_document_body(document)
        );
        (batch, pending) = _firestore_batch_after_write(
            self.client, batch, pending
        );
    }

    _firestore_batch_finalize(batch, pending);
    return InsertManyResult(inserted_ids=inserted_ids);
}

impl FirestoreDb.update_many(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> UpdateResult {
    _validate_not_read_only(col_name);
    query = _apply_firestore_filters(
        self._get_firestore_collection(col_name), filter
    );
    update_fields = _firestore_update_fields(update_data);

    # Stream matches straight into batches rather than materializing the
    # whole result set: memory stays bounded to one batch (500 writes).
    batch = self.client.batch();
    pending = 0;
    modified_count = 0;

    for snapshot in query.stream() {
        batch.update(
            self._get_firestore_collection(col_name).document(snapshot.id),
            update_fields
        );
        modified_count += 1;
        (batch, pending) = _firestore_batch_after_write(
            self.client, batch, pending
        );
    }

    if modified_count == 0 {
        if not upsert_mode {
            return UpdateResult(matched_count=0, modified_count=0);
        }
        seed_document = _firestore_seed_document(filter, update_data);
        doc_id = _firestore_document_id(seed_document) or str(uuid4());
        self._get_firestore_collection(col_name).document(doc_id).set(
            _firestore_document_body(seed_document), merge=True
        );
        return UpdateResult(matched_count=0, modified_count=0, upserted_id=doc_id);
    }

    _firestore_batch_finalize(batch, pending);
    return UpdateResult(
        matched_count=modified_count, modified_count=modified_count
    );
}

impl FirestoreDb.delete_many(
    col_name: str, filter: dict
) -> DeleteResult {
    _validate_not_read_only(col_name);
    query = _apply_firestore_filters(
        self._get_firestore_collection(col_name), filter
    );

    # Stream matches straight into batches rather than materializing the
    # whole result set: memory stays bounded to one batch (500 writes).
    batch = self.client.batch();
    pending = 0;
    deleted_count = 0;

    for snapshot in query.stream() {
        batch.delete(
            self._get_firestore_collection(col_name).document(snapshot.id)
        );
        deleted_count += 1;
        (batch, pending) = _firestore_batch_after_write(
            self.client, batch, pending
        );
    }

    _firestore_batch_finalize(batch, pending);
    return DeleteResult(deleted_count=deleted_count);
}

impl FirestoreDb.find_by_id(col_name: str, id: str) -> dict | None {
    snapshot = self._get_firestore_collection(col_name).document(id).get();
    return _firestore_snapshot_to_doc(snapshot);
}

impl FirestoreDb.update_by_id(
    col_name: str, id: str, update_data: dict, upsert_mode: bool = False
) -> UpdateResult {
    _validate_not_read_only(col_name);
    doc_ref = self._get_firestore_collection(col_name).document(id);
    exists = doc_ref.get().exists;
    if not exists and not upsert_mode {
        return UpdateResult(matched_count=0, modified_count=0);
    }

    update_fields = _firestore_update_fields(update_data);
    if exists {
        doc_ref.update(update_fields);
        return UpdateResult(matched_count=1, modified_count=1);
    }

    doc_ref.set(update_fields, merge=True);
    return UpdateResult(matched_count=0, modified_count=0, upserted_id=id);
}

impl FirestoreDb.delete_by_id(col_name: str, id: str) -> DeleteResult {
    _validate_not_read_only(col_name);
    # Firestore delete() is a no-op when the document doesn't exist (no error
    # thrown), so we skip the pre-read and return 1 optimistically.  This
    # saves one billed read per call.  Callers that need an exact count
    # should call find_by_id() first.
    doc_ref = self._get_firestore_collection(col_name).document(id);
    doc_ref.delete();
    return DeleteResult(deleted_count=1);
}
