import from uuid { uuid4 }
import from jaclang.scale._optdeps.firestore { NotFound, AlreadyExists }
import from jaclang.scale._optdeps.pymongo { DuplicateKeyError }
import from jaclang.scale.persistence._db_helpers { _validate_not_read_only }

def _firestore_collection_name(db_name: str, col_name: str) -> str {
    if '__' in db_name or '__' in col_name {
        raise ValueError(
            f"Firestore collection name components must not contain '__': "
            f"db_name={db_name!r}, col_name={col_name!r}"
        );
    }
    return f"{db_name}__{col_name}";
}

def _firestore_snapshot_to_doc(snapshot: any) -> dict | None {
    if not (snapshot and snapshot.exists) {
        return None;
    }

    data = snapshot.to_dict() or {};
    data['_id'] = snapshot.id;
    return data;
}

def _firestore_document_id(document: dict) -> str | None {
    if (doc_id := document.get('_id')) is None {
        return None;
    }
    return str(doc_id);
}

def _firestore_document_body(document: dict) -> dict {
    body = document.copy();
    if '_id' in body {
        del body['_id'];
    }
    return body;
}

glob _SUPPORTED_UPDATE_OPERATORS: frozenset = frozenset(['$set']);

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

def _apply_firestore_field_filter(
    query: any, field_name: str, op: str, value: any
) -> any {
    import from google.cloud.firestore_v1 { FieldFilter }
    return query.where(filter=FieldFilter(field_name, op, value));
}

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

def _apply_firestore_projection(query: any, plan: dict | None) -> any {
    if plan is not None and plan['mode'] == 'include' and plan['fields'] {
        return query.select(plan['fields']);
    }
    return query;
}

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

def _firestore_batch_finalize(batch: any, pending: int) {
    if pending > 0 {
        batch.commit();
    }
}

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

def _firestore_delete_doc_ref(doc_ref: any) -> int {
    if not doc_ref.get().exists {
        return 0;
    }
    doc_ref.delete();
    return 1;
}


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
