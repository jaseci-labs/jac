"""Firestore implementation for FirestoreDb."""
import from uuid { uuid4 }
import from google.cloud.exceptions { NotFound }
import from google.api_core.exceptions { AlreadyExists }
import from jac_scale._optdeps.pymongo { DuplicateKeyError }
import from jac_scale._db_helpers { _validate_not_read_only }

# ===== FIRESTORE HELPERS =====
"""Generate Firestore collection name with db namespace.

Uses `__` as a separator. Raises ValueError if `db_name` or `col_name`
contains `__` to prevent ambiguous collection paths.
"""
def _firestore_collection_name(db_name: str, col_name: str) -> str {
    if '__' in db_name or '__' in col_name {
        raise ValueError(
            f"Firestore collection name components must not contain '__': "
            f"db_name={db_name!r}, col_name={col_name!r}"
        );
    }
    return f"{db_name}__{col_name}";
}

"""Convert a Firestore document snapshot into a kvstore document."""
def _firestore_snapshot_to_doc(snapshot: any) -> dict | None {
    if not (snapshot and snapshot.exists) {
        return None;
    }

    data = snapshot.to_dict() or {};
    data['_id'] = snapshot.id;
    return data;
}

"""Return the explicit Firestore document ID from a document, if provided."""
def _firestore_document_id(document: dict) -> str | None {
    if (doc_id := document.get('_id')) is None {
        return None;
    }
    return str(doc_id);
}

"""Strip kvstore-managed _id before writing a Firestore document."""
def _firestore_document_body(document: dict) -> dict {
    body = document.copy();
    if '_id' in body {
        del body['_id'];
    }
    return body;
}

glob _SUPPORTED_UPDATE_OPERATORS: frozenset = frozenset(['$set']);

"""Convert Mongo-style update payloads into Firestore field updates.

Only `$set` and flat field maps are supported. Passing `$inc`, `$unset`,
`$push`, or other Mongo operators raises ValueError rather than silently
writing a field named `'$inc'` etc. to Firestore.
"""
def _firestore_update_fields(update_data: dict) -> dict {
    for key in update_data {
        if key.startswith('$') and key not in _SUPPORTED_UPDATE_OPERATORS {
            raise ValueError(
                f"Unsupported update operator '{key}' for Firestore. "
                "Only '$set' and flat field maps are supported. "
                "Use Firestore-native operations for '$inc', '$unset', etc."
            );
        }
    }
    fields = update_data['$set'].copy()
        if '$set' in update_data
        else update_data.copy();
    if '_id' in fields {
        del fields['_id'];
    }
    return fields;
}

glob _FIRESTORE_OPERATOR_MAP: dict[str, str] = {
         '$eq': '==',
         '$ne': '!=',
         '$gt': '>',
         '$gte': '>=',
         '$lt': '<',
         '$lte': '<=',
         '$in': 'in',
         '$nin': 'not-in'
     },
     _FIRESTORE_BATCH_LIMIT: int = 500;

"""Apply a single Firestore field filter using the keyword-arg API."""
def _apply_firestore_field_filter(
    query: any, field_name: str, op: str, value: any
) -> any {
    import from google.cloud.firestore_v1 { FieldFilter }
    return query.where(filter=FieldFilter(field_name, op, value));
}

"""Apply a single Firestore field filter from a kvstore filter value."""
def _apply_firestore_field_value(query: any, field_name: str, value: any) -> any {
    if isinstance(value, dict) {
        current_query = query;
        for (operator, operator_value) in value.items() {
            if operator not in _FIRESTORE_OPERATOR_MAP {
                raise ValueError(f'Unsupported Firestore filter operator: {operator}');
            }
            current_query = _apply_firestore_field_filter(
                current_query,
                field_name,
                _FIRESTORE_OPERATOR_MAP[operator],
                operator_value
            );
        }
        return current_query;
    }

    return _apply_firestore_field_filter(query, field_name, '==', value);
}

"""Apply kvstore filters to a Firestore query."""
def _apply_firestore_filters(query: any, filter: dict) -> any {
    current_query = query;

    for (field_name, value) in filter.items() {
        if field_name == '$and' {
            for clause in value {
                current_query = _apply_firestore_filters(current_query, clause);
            }
        } elif field_name == '$or' {
            raise NotImplementedError(
                'Firestore kvstore does not support $or filters. '
                'Restructure the query or run multiple finds.'
            );
        } elif field_name == '_id' {
            raise NotImplementedError(
                'Filtering by _id is not supported for Firestore queries. '
                'Use get(), find_by_id(), update_by_id(), or delete_by_id() instead.'
            );
        } else {
            current_query = _apply_firestore_field_value(
                current_query, field_name, value
            );
        }
    }

    return current_query;
}

"""Parse a Mongo-style projection into a Firestore projection plan.

Returns None when no projection is requested. Otherwise a dict with:
  'mode'   : 'include' or 'exclude'
  'fields' : the non-_id field names to include (include) or strip (exclude)
  'drop_id': whether _id should be removed from the result

Firestore has no server-side field exclusion, so exclusion is applied
client-side after the read; inclusion uses query.select() for a smaller,
cheaper read. Mixing inclusion and exclusion (other than _id) raises, matching
pymongo's projection rules.
"""
def _firestore_projection_plan(projection: dict | None) -> dict | None {
    if not projection {
        return None;
    }
    drop_id = projection.get('_id', 1) in (0, False);
    include_fields: list = [];
    exclude_fields: list = [];
    for (field, flag) in projection.items() {
        if field == '_id' {
            continue;
        }
        if flag in (0, False) {
            exclude_fields.append(field);
        } else {
            include_fields.append(field);
        }
    }
    if include_fields and exclude_fields {
        raise ValueError(
            'Cannot mix inclusion and exclusion in a projection (except _id).'
        );
    }
    if include_fields {
        return {'mode': 'include', 'fields': include_fields, 'drop_id': drop_id};
    }
    return {'mode': 'exclude', 'fields': exclude_fields, 'drop_id': drop_id};
}

"""Apply an inclusion projection to a Firestore query via query.select().

Exclusion projections have no server-side equivalent and are handled
client-side in _project_firestore_doc, so they pass through untouched here."""
def _apply_firestore_projection(query: any, plan: dict | None) -> any {
    if plan is not None and plan['mode'] == 'include' and plan['fields'] {
        return query.select(plan['fields']);
    }
    return query;
}

"""Shape a Firestore document dict to match a projection plan.

For inclusion, keeps only the requested fields (plus _id unless suppressed).
For exclusion, removes the listed fields. _id is dropped when the projection
set _id: 0. Returns the doc unchanged when no projection is in effect."""
def _project_firestore_doc(doc: dict | None, plan: dict | None) -> dict | None {
    if doc is None or plan is None {
        return doc;
    }
    if plan['mode'] == 'include' {
        result: dict = {};
        for field in plan['fields'] {
            if field in doc {
                result[field] = doc[field];
            }
        }
        if not plan['drop_id'] and '_id' in doc {
            result['_id'] = doc['_id'];
        }
        return result;
    }
    result = doc.copy();
    for field in plan['fields'] {
        if field in result {
            del result[field];
        }
    }
    if plan['drop_id'] and '_id' in result {
        del result['_id'];
    }
    return result;
}

"""Bump pending count and flush the Firestore batch when the limit is reached."""
def _firestore_batch_after_write(
    client: any, batch: any, pending: int
) -> tuple[any, int] {
    pending += 1;
    if pending >= _FIRESTORE_BATCH_LIMIT {
        batch.commit();
        return (client.batch(), 0);
    }
    return (batch, pending);
}

"""Commit a partially filled Firestore batch."""
def _firestore_batch_finalize(batch: any, pending: int) {
    if pending > 0 {
        batch.commit();
    }
}

"""Commit a batch of update() writes, tolerating concurrently-deleted docs.

A Firestore batch is atomic: if any document in `refs` was deleted between the
query stream and this commit, the whole commit raises NotFound and nothing is
written. Replay each update individually in that case, skipping docs that no
longer exist, and return the number actually updated.
"""
def _firestore_commit_updates(batch: any, refs: list, update_fields: dict) -> int {
    if not refs {
        return 0;
    }
    try {
        batch.commit();
        return len(refs);
    } except NotFound {
        written = 0;
        for ref in refs {
            try {
                ref.update(update_fields);
                written += 1;
            } except NotFound {
                continue;
            }
        }
        return written;
    }
}

"""Commit a Firestore insert batch, translating duplicate-id conflicts.

A create() batch is atomic and insert-only: if any document's _id already
exists, the whole commit raises AlreadyExists and nothing is written. Translate
that to DuplicateKeyError for parity with the Mongo backend's duplicate-insert
behavior instead of leaking the vendor exception.
"""
def _firestore_commit_inserts(batch: any, pending: int) {
    if pending == 0 {
        return;
    }
    try {
        batch.commit();
    } except AlreadyExists {
        raise DuplicateKeyError(
            "insert_many: a document with a supplied _id already exists"
        );
    }
}

"""Build a best-effort Firestore document for upsert from filter + update.

Note: callers pass this to set(merge=True), which deep-merges nested dicts by
key — not dotted-path semantics. For the kvstore-style flat documents this API
targets, that is correct; callers with nested update payloads should be aware
of the difference from Firestore's update() dotted-path expansion.
"""
def _firestore_seed_document(filter: dict, update_data: dict) -> dict {
    seed: dict = {};

    for (field_name, value) in filter.items() {
        if field_name.startswith('$') {
            continue;
        }
        if not isinstance(value, dict) {
            seed[field_name] = value;
        }
    }

    seed.update(_firestore_update_fields(update_data));
    return seed;
}

"""Delete a Firestore document when present; return 1 if deleted, else 0."""
def _firestore_delete_doc_ref(doc_ref: any) -> int {
    if not doc_ref.get().exists {
        return 0;
    }
    doc_ref.delete();
    return 1;
}


# ===== FIRESTORE_DB IMPLEMENTATIONS =====
impl FirestoreDb._get_firestore_collection(col_name: str) -> any {
    return self.client.collection(_firestore_collection_name(self.db_name, col_name));
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
    doc_ref = self._get_firestore_collection(col_name).document(key);
    return _firestore_delete_doc_ref(doc_ref);
}

impl FirestoreDb.exists(key: str, col_name: str = 'default') -> bool {
    return self._get_firestore_collection(col_name).document(key).get().exists;
}

impl FirestoreDb.find_one(
    col_name: str, filter: dict, projection: dict | None = None
) -> dict | None {
    plan = _firestore_projection_plan(projection);
    query = _apply_firestore_filters(self._get_firestore_collection(col_name), filter);
    query = _apply_firestore_projection(query, plan);
    results = list(query.limit(1).stream());
    if not results {
        return None;
    }
    return _project_firestore_doc(_firestore_snapshot_to_doc(results[0]), plan);
}

impl FirestoreDb.find(
    col_name: str,
    filter: dict,
    projection: dict | None = None,
    limit: int | None = None
) -> list {
    plan = _firestore_projection_plan(projection);
    query = _apply_firestore_filters(self._get_firestore_collection(col_name), filter);
    query = _apply_firestore_projection(query, plan);
    if limit is not None {
        query = query.limit(limit);
    }
    results: list = [];
    for snapshot in query.stream() {
        if (doc := _firestore_snapshot_to_doc(snapshot)) is not None {
            results.append(_project_firestore_doc(doc, plan));
        }
    }
    return results;
}

impl FirestoreDb.count_documents(col_name: str, filter: dict) -> int {
    query = _apply_firestore_filters(self._get_firestore_collection(col_name), filter);
    results = query.count().get();
    return results[0][0].value if results else 0;
}

impl FirestoreDb.create_index(
    col_name: str, keys: dict, unique: bool = False, name: str | None = None
) -> str {
    raise NotImplementedError(
        "Firestore indexes are managed via the Firebase console or "
        "firestore.indexes.json, not through the SDK. "
        "See https://firebase.google.com/docs/firestore/query-data/indexing"
    );
}

impl FirestoreDb.insert_one(col_name: str, document: dict) -> InsertResult {
    _validate_not_read_only(col_name);
    doc_id = _firestore_document_id(document) or str(uuid4());
    # create() is insert-only: a pre-existing _id raises AlreadyExists. Translate
    # it to DuplicateKeyError so callers get the same predictable error the Mongo
    # backend raises on a duplicate insert, instead of a leaked vendor exception.
    try {
        self._get_firestore_collection(col_name).document(doc_id).create(
            _firestore_document_body(document)
        );
    } except AlreadyExists {
        raise DuplicateKeyError(
            f"Document with _id '{doc_id}' already exists in '{col_name}'"
        );
    }
    return InsertResult(inserted_id=doc_id);
}

impl FirestoreDb.update_one(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> UpdateResult {
    _validate_not_read_only(col_name);
    query = _apply_firestore_filters(self._get_firestore_collection(col_name), filter);
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

    # The query (line ~373) and this update are non-transactional, so a
    # concurrent delete can make .update() raise NotFound. The abstract
    # interface signals "not found" via matched_count=0, so translate the
    # race into that result instead of letting the exception escape.
    try {
        self._get_firestore_collection(col_name).document(results[0].id).update(
            update_fields
        );
    } except NotFound {
        return UpdateResult(matched_count=0, modified_count=0);
    }
    return UpdateResult(matched_count=1, modified_count=1);
}

impl FirestoreDb.delete_one(col_name: str, filter: dict) -> DeleteResult {
    _validate_not_read_only(col_name);
    query = _apply_firestore_filters(self._get_firestore_collection(col_name), filter);
    results = list(query.limit(1).stream());
    if not results {
        return DeleteResult(deleted_count=0);
    }
    self._get_firestore_collection(col_name).document(results[0].id).delete();
    return DeleteResult(deleted_count=1);
}

impl FirestoreDb.insert_many(col_name: str, documents: list) -> InsertManyResult {
    _validate_not_read_only(col_name);
    col = self._get_firestore_collection(col_name);
    inserted_ids: list = [];
    batch = self.client.batch();
    pending = 0;

    for document in documents {
        doc_id = _firestore_document_id(document) or str(uuid4());
        inserted_ids.append(doc_id);
        batch.create(col.document(doc_id), _firestore_document_body(document));
        pending += 1;
        if pending >= _FIRESTORE_BATCH_LIMIT {
            _firestore_commit_inserts(batch, pending);
            batch = self.client.batch();
            pending = 0;
        }
    }

    _firestore_commit_inserts(batch, pending);
    return InsertManyResult(inserted_ids=inserted_ids);
}

impl FirestoreDb.update_many(
    col_name: str, filter: dict, update_data: dict, upsert_mode: bool = False
) -> UpdateResult {
    _validate_not_read_only(col_name);
    col = self._get_firestore_collection(col_name);
    query = _apply_firestore_filters(col, filter);
    update_fields = _firestore_update_fields(update_data);

    # Stream matches straight into batches rather than materializing the
    # whole result set: memory stays bounded to one batch (500 writes).
    # Track the refs per batch so a commit failed by a concurrent delete can
    # be replayed per-document (see _firestore_commit_updates).
    batch = self.client.batch();
    refs: list = [];
    matched_count = 0;
    modified_count = 0;

    for snapshot in query.stream() {
        ref = col.document(snapshot.id);
        batch.update(ref, update_fields);
        refs.append(ref);
        matched_count += 1;
        if len(refs) >= _FIRESTORE_BATCH_LIMIT {
            modified_count += _firestore_commit_updates(batch, refs, update_fields);
            batch = self.client.batch();
            refs = [];
        }
    }

    # Upsert only when nothing matched the query at all; matches that all got
    # concurrently deleted (matched_count > 0, modified_count == 0) are not
    # treated as a miss.
    if matched_count == 0 {
        if not upsert_mode {
            return UpdateResult(matched_count=0, modified_count=0);
        }
        seed_document = _firestore_seed_document(filter, update_data);
        doc_id = _firestore_document_id(seed_document) or str(uuid4());
        col.document(doc_id).set(_firestore_document_body(seed_document), merge=True);
        return UpdateResult(matched_count=0, modified_count=0, upserted_id=doc_id);
    }

    modified_count += _firestore_commit_updates(batch, refs, update_fields);
    return UpdateResult(matched_count=matched_count, modified_count=modified_count);
}

impl FirestoreDb.delete_many(col_name: str, filter: dict) -> DeleteResult {
    _validate_not_read_only(col_name);
    col = self._get_firestore_collection(col_name);
    query = _apply_firestore_filters(col, filter);

    # Stream matches straight into batches rather than materializing the
    # whole result set: memory stays bounded to one batch (500 writes).
    batch = self.client.batch();
    pending = 0;
    deleted_count = 0;

    for snapshot in query.stream() {
        batch.delete(col.document(snapshot.id));
        deleted_count += 1;
        (batch, pending) = _firestore_batch_after_write(self.client, batch, pending);
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
        # The get() above and this update() are non-transactional, so a
        # concurrent delete can make .update() raise NotFound. Translate the
        # race into matched_count=0 (parity with update_one) instead of
        # letting the vendor exception escape.
        try {
            doc_ref.update(update_fields);
        } except NotFound {
            return UpdateResult(matched_count=0, modified_count=0);
        }
        return UpdateResult(matched_count=1, modified_count=1);
    }

    doc_ref.set(update_fields, merge=True);
    return UpdateResult(matched_count=0, modified_count=0, upserted_id=id);
}

impl FirestoreDb.delete_by_id(col_name: str, id: str) -> DeleteResult {
    _validate_not_read_only(col_name);
    doc_ref = self._get_firestore_collection(col_name).document(id);
    return DeleteResult(deleted_count=_firestore_delete_doc_ref(doc_ref));
}
