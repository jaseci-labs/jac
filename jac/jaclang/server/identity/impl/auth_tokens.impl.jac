impl AuthTokenStore.postinit -> None {
    self._in_memory = {};
    try {
        import from jaclang.server.shared_store { shared_store }
        self._db = shared_store();
    } except Exception as e {
        logger.warning(f"database unavailable for auth tokens: {e}");
        self._db = None;
    }
    if self._db is None {
        logger.warning(
            "AuthTokenStore is using in-memory storage because no database "
            "is reachable. Tokens issued by one worker will not be visible "
            "to the others; set JAC_DB_URL or [scale.database] url."
        );
    }
}


impl AuthTokenStore.instance -> AuthTokenStore {
    if _auth_token_store is not None {
        return _auth_token_store;
    }
    _auth_token_store = AuthTokenStore();
    return _auth_token_store;
}

impl reset_auth_token_store -> None {
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

impl AuthTokenStore.peek_token(token: str, purpose: str) -> (dict[str, any] | None) {
    record = self._find(AuthTokenStore.hash_token(token), purpose);
    if record is None {
        return None;
    }
    if _is_expired(record) {
        self._delete(record.get('token_hash', ''));
        return None;
    }
    return record;
}

impl AuthTokenStore.consume_token(token: str, purpose: str) -> (dict[str, any] | None) {
    record = self.peek_token(token, purpose);
    if record is None {
        return None;
    }

    if not self._delete(record.get('token_hash', '')) {
        return None;
    }
    return record;
}

impl AuthTokenStore.revoke_user_tokens(user_id: str, purpose: str) -> int {
    return self._delete_user(user_id, purpose);
}

impl AuthTokenStore._persist(record: dict[str, any]) -> None {
    if self._db is not None {
        try {
            import json;
            expires_at: datetime = record['expires_at'];
            ttl = expires_at - datetime.now(UTC);
            self._db.rows(
                """
                INSERT INTO kv_state (key, value, expires_at)
                VALUES (:k, :v, now() + make_interval(secs => CAST(:ttl AS float8)))
                ON CONFLICT (key) DO UPDATE SET
                    value = EXCLUDED.value, expires_at = EXCLUDED.expires_at
                """,
                {
                    'k': f"authtok:{record['token_hash']}",
                    'v': json.dumps(dict(record), `default=str),
                    'ttl': max(1.0, ttl.total_seconds())
                }
            );
            return;
        } except Exception as e {
            logger.error(f"database persist failed for auth token: {e}");
            raise RuntimeError(
                'auth token could not be persisted; refusing to mint a token '
                'only one worker could redeem'
            ) from e;
        }
    }
    self._in_memory[record['token_hash']] = dict(record);
}

impl AuthTokenStore._find(token_hash: str, purpose: str) -> (dict[str, any] | None) {
    if self._db is not None {
        try {
            import json;
            got = self._db.kv_get(f"authtok:{token_hash}");
            if got is None {
                return None;
            }
            doc = json.loads(got);
            return doc if doc.get('purpose') == purpose else None;
        } except Exception as e {
            logger.error(f"database find failed for auth token: {e}");
            return None;
        }
    }
    record = self._in_memory.get(token_hash);
    if record is None or record.get('purpose') != purpose {
        return None;
    }
    return record;
}

impl AuthTokenStore._delete(token_hash: str) -> bool {
    if self._db is not None {
        try {
            rows = self._db.rows(
                'DELETE FROM kv_state WHERE key = :k RETURNING key',
                {'k': f"authtok:{token_hash}"}
            );
            return bool(rows);
        } except Exception as e {
            logger.error(f"database delete failed for auth token: {e}");
            return False;
        }
    }
    return self._in_memory.pop(token_hash, None) is not None;
}

impl AuthTokenStore._delete_user(user_id: str, purpose: str) -> int {
    if self._db is not None {
        try {
            rows = self._db.rows(
                """
                DELETE FROM kv_state
                WHERE key LIKE 'authtok:%'
                      AND value::jsonb->>'user_id' = :u
                      AND value::jsonb->>'purpose' = :p
                RETURNING key
                """,
                {'u': user_id, 'p': purpose}
            );
            return len(rows);
        } except Exception as e {
            logger.error(f"database delete_many failed for auth token: {e}");
            return 0;
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

def _is_expired(record: dict[str, any]) -> bool {
    raw_expires = record.get('expires_at');
    if raw_expires is None {
        return False;
    }
    if isinstance(raw_expires, str) {
        try {
            expires_at: datetime = datetime.fromisoformat(
                raw_expires.replace('Z', '+00:00')
            );
        } except Exception {
            return False;
        }
    } else {
        expires_at = raw_expires;
    }
    if expires_at.tzinfo is None {
        expires_at = expires_at.replace(tzinfo=UTC);
    }
    return datetime.now(UTC) >= expires_at;
}
