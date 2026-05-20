"""Auth token store implementation: SHA256 hashing, TTL, single-use, Mongo+memory."""

impl AuthTokenStore.postinit -> None {
    auth_cfg = get_scale_config().get_auth_config();
    self._collection = auth_cfg.get('token_collection', 'auth_tokens');
    self._in_memory = {};
    db_cfg = get_scale_config().get_database_config();
    if db_cfg.get('mongodb_uri') {
        try {
            self._db = Db(client=get_mongo_client(), db_name='jac_scale');
            # TTL index on expires_at - Mongo prunes expired records automatically.
            try {
                self._db.client['jac_scale'][self._collection].create_index(
                    'expires_at', expireAfterSeconds=0
                );
                self._db.client['jac_scale'][self._collection].create_index(
                    'token_hash', unique=True
                );
            } except Exception as e {
                logger.debug(f"Could not create auth_tokens indexes: {e}");
            }
        } except Exception as e {
            logger.warning(
                f"MongoDB unavailable for auth tokens, using in-memory: {e}"
            );
            self._db = None;
        }
    }
}

impl AuthTokenStore.instance -> AuthTokenStore {
    global _auth_token_store;
    if _auth_token_store is not None {
        return _auth_token_store;
    }
    _auth_token_store = AuthTokenStore();
    return _auth_token_store;
}

impl reset_auth_token_store -> None {
    global _auth_token_store;
    _auth_token_store = None;
}

impl AuthTokenStore.hash_token(token: str) -> str {
    return hashlib.sha256(token.encode('utf-8')).hexdigest();
}

impl AuthTokenStore.create_token(
    user_id: str, purpose: str, ttl_seconds: int, identity_value: (str | None) = None
) -> str {
    raw = secrets.token_urlsafe(32);
    expires_at = datetime.now(UTC) + timedelta(seconds=ttl_seconds);
    record = {
        '_id': str(uuid4()),
        'token_hash': AuthTokenStore.hash_token(raw),
        'user_id': user_id,
        'purpose': purpose,
        'identity_value': identity_value,
        'expires_at': expires_at,
        'created_at': datetime.now(UTC)
    };
    self._persist(record);
    return raw;
}

impl AuthTokenStore.peek_token(token: str, purpose: str) -> (dict[str, Any] | None) {
    record = self._find(AuthTokenStore.hash_token(token), purpose);
    if record is None {
        return None;
    }
    if _is_expired(record) {
        # Best-effort clean-up; in-memory store needs explicit deletion.
        self._delete(record.get('token_hash', ''));
        return None;
    }
    return record;
}

impl AuthTokenStore.consume_token(token: str, purpose: str) -> (dict[str, Any] | None) {
    record = self.peek_token(token, purpose);
    if record is None {
        return None;
    }
    # Single-use arbitration: only the caller whose _delete actually removed
    # the record wins. Concurrent consumers of the same token get None here.
    if not self._delete(record.get('token_hash', '')) {
        return None;
    }
    return record;
}

impl AuthTokenStore.revoke_user_tokens(user_id: str, purpose: str) -> int {
    return self._delete_user(user_id, purpose);
}

"""Storage primitive: insert a record into Mongo or fallback dict."""
impl AuthTokenStore._persist(record: dict[str, Any]) -> None {
    if self._db is not None {
        try {
            self._db.insert_one(self._collection, dict(record));
            return;
        } except Exception as e {
            logger.warning(
                f"MongoDB persist failed for auth token, using in-memory: {e}"
            );
        }
    }
    self._in_memory[record['token_hash']] = dict(record);
}

"""Storage primitive: look up a record by hash + purpose."""
impl AuthTokenStore._find(token_hash: str, purpose: str) -> (dict[str, Any] | None) {
    if self._db is not None {
        try {
            doc = self._db.find_one(
                self._collection, {'token_hash': token_hash, 'purpose': purpose}
            );
            return doc;
        } except Exception as e {
            logger.warning(f"MongoDB find failed for auth token, using in-memory: {e}");
        }
    }
    record = self._in_memory.get(token_hash);
    if record is None or record.get('purpose') != purpose {
        return None;
    }
    return record;
}

"""Storage primitive: atomically remove a record by hash."""
impl AuthTokenStore._delete(token_hash: str) -> bool {
    if self._db is not None {
        try {
            result = self._db.delete_one(self._collection, {'token_hash': token_hash});
            return result.deleted_count > 0;
        } except Exception as e {
            logger.warning(
                f"MongoDB delete failed for auth token, using in-memory: {e}"
            );
        }
    }
    return self._in_memory.pop(token_hash, None) is not None;
}

"""Storage primitive: delete all (user_id, purpose) records."""
impl AuthTokenStore._delete_user(user_id: str, purpose: str) -> int {
    if self._db is not None {
        try {
            result = self._db.delete_many(
                self._collection, {'user_id': user_id, 'purpose': purpose}
            );
            return result.deleted_count;
        } except Exception as e {
            logger.warning(
                f"MongoDB delete_many failed for auth token, using in-memory: {e}"
            );
        }
    }
    to_delete = [
        h
        for (h, r) in self._in_memory.items()
        if r.get('user_id') == user_id and r.get('purpose') == purpose
    ];
    for h in to_delete {
        del self._in_memory[h];
    }
    return len(to_delete);
}

"""Internal: detect expired records (handles datetime objects + ISO strings)."""
def _is_expired(record: dict[str, Any]) -> bool {
    expires_at = record.get('expires_at');
    if expires_at is None {
        return False;
    }
    if isinstance(expires_at, str) {
        try {
            expires_at = datetime.fromisoformat(expires_at.replace('Z', '+00:00'));
        } except Exception {
            return False;
        }
    }
    if expires_at.tzinfo is None {
        expires_at = expires_at.replace(tzinfo=UTC);
    }
    return datetime.now(UTC) >= expires_at;
}
