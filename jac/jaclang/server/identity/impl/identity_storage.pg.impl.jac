glob _PG_IDENTITY_SCHEMA: list[str] = [
         """
    CREATE TABLE IF NOT EXISTS identity_users (
        user_id text PRIMARY KEY,
        doc     jsonb NOT NULL
    )
    """,
         """
    CREATE TABLE IF NOT EXISTS identity_lookups (
        value_normalized text PRIMARY KEY,
        user_id          text NOT NULL
    )
    """,
         """
    CREATE TABLE IF NOT EXISTS sso_lookups (
        provider    text NOT NULL,
        external_id text NOT NULL,
        user_id     text NOT NULL,
        PRIMARY KEY (provider, external_id)
    )
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_identity_lookups_user
        ON identity_lookups (user_id)
    """
     ];


def _pg_json_default(o: object) -> str {
    return str(o);
}


def _pg_unique_violation(e: Exception) -> bool {
    for arg in getattr(e, 'args', ()) {
        if isinstance(arg, dict) and arg.get('C') == '23505' {
            return True;
        }
    }
    return False;
}


def _pg_load_doc(raw: any) -> dict[str, any] {
    return raw if isinstance(raw, dict) else json.loads(str(raw));
}


def _pg_public(raw: any) -> dict[str, any] {
    d = _pg_load_doc(raw);
    return {
        'user_id': d.get('user_id'),
        'status': d.get('status') or 'active',
        'identities': d.get('identities') or [],
        'root_id': d.get('root_id') or None,
        'role': d.get('role') or 'user',
        'requires_password_reset': bool(d.get('requires_password_reset')),
        'profile': d.get('profile') or {},
        'created_at': d.get('created_at'),
        'updated_at': d.get('updated_at')
    };
}


impl PgIdentityStorage.postinit -> None {
    self.ensure_indexes();
}

impl PgIdentityStorage.ensure_indexes -> None {
    for stmt in _PG_IDENTITY_SCHEMA {
        self.store.rows(stmt, {});
    }
}

impl PgIdentityStorage._store_user(user_doc: dict[str, any]) -> None {
    user_id = str(user_doc['user_id']);
    self.store.rows(
        """
        INSERT INTO identity_users (user_id, doc)
        VALUES (:u, CAST(:d AS jsonb))
        """,
        {'u': user_id, 'd': json.dumps(user_doc, `default=_pg_json_default)}
    );
    for identity in user_doc.get('identities', []) {
        if identity.get('type') == 'sso' and identity.get('provider') {
            self.store.rows(
                """
                INSERT INTO sso_lookups (provider, external_id, user_id)
                VALUES (:p, :e, :u) ON CONFLICT DO NOTHING
                """,
                {
                    'p': identity['provider'],
                    'e': identity.get('external_id', ''),
                    'u': user_id
                }
            );
        } elif identity.get('value_normalized') {
            self.store.rows(
                """
                INSERT INTO identity_lookups (value_normalized, user_id)
                VALUES (:v, :u) ON CONFLICT DO NOTHING
                """,
                {'v': identity['value_normalized'], 'u': user_id}
            );
        }
    }
}

impl PgIdentityStorage.get_user_by_id(user_id: str) -> dict[str, any] | None {
    rows = self.store.rows(
        'SELECT doc FROM identity_users WHERE user_id = :u', {'u': user_id}
    );
    return _pg_public(rows[0][0]) if rows else None;
}

impl PgIdentityStorage.find_user_by_identity(value: str) -> dict[str, any] | None {
    normalized = value.lower().strip();
    rows = self.store.rows(
        """
        SELECT t.doc FROM identity_users t
        JOIN identity_lookups lk ON t.user_id = lk.user_id
        WHERE lk.value_normalized = :v
          AND COALESCE(t.doc->>'status', 'active') <> 'disabled'
        """,
        {'v': normalized}
    );
    return _pg_public(rows[0][0]) if rows else None;
}

impl PgIdentityStorage.identity_taken(value: str) -> bool {
    normalized = value.lower().strip();
    rows = self.store.rows(
        """
        SELECT 1 FROM identity_lookups lk
        JOIN identity_users t ON lk.user_id = t.user_id
        WHERE lk.value_normalized = :v
          AND COALESCE(t.doc->>'status', 'active') <> 'disabled'
        """,
        {'v': normalized}
    );
    return bool(rows);
}

impl PgIdentityStorage.delete_user(user_id: str) -> bool {
    self.store.rows('DELETE FROM identity_lookups WHERE user_id = :u', {'u': user_id});
    self.store.rows('DELETE FROM sso_lookups WHERE user_id = :u', {'u': user_id});
    rows = self.store.rows(
        'DELETE FROM identity_users WHERE user_id = :u RETURNING user_id',
        {'u': user_id}
    );
    return bool(rows);
}

impl PgIdentityStorage._update_fields(user_id: str, fields: dict[str, any]) -> bool {
    allowed = {
        'status',
        'root_id',
        'role',
        'requires_password_reset',
        'profile',
        'updated_at'
    };
    safe_fields = {
        k: v
        for (k, v) in fields.items()
        if k in allowed
    };
    if not safe_fields {
        return False;
    }
    rows = self.store.rows(
        """
        UPDATE identity_users SET doc = doc || CAST(:p AS jsonb)
        WHERE user_id = :u RETURNING user_id
        """,
        {'u': user_id, 'p': json.dumps(safe_fields, `default=_pg_json_default)}
    );
    return bool(rows);
}

impl PgIdentityStorage._get_credentials(user_id: str) -> list[dict[str, any]] {
    rows = self.store.rows(
        'SELECT doc FROM identity_users WHERE user_id = :u', {'u': user_id}
    );
    if not rows {
        return [];
    }
    return _pg_load_doc(rows[0][0]).get('credentials') or [];
}

impl PgIdentityStorage._update_credentials(
    user_id: str, credentials: list[dict[str, any]]
) -> None {
    patch = {'credentials': credentials, 'updated_at': datetime.now(UTC).isoformat()};
    self.store.rows(
        """
        UPDATE identity_users SET doc = doc || CAST(:p AS jsonb)
        WHERE user_id = :u
        """,
        {'u': user_id, 'p': json.dumps(patch, `default=_pg_json_default)}
    );
}

impl PgIdentityStorage._get_identities(user_id: str) -> list[dict[str, any]] {
    rows = self.store.rows(
        'SELECT doc FROM identity_users WHERE user_id = :u', {'u': user_id}
    );
    if not rows {
        return [];
    }
    return _pg_load_doc(rows[0][0]).get('identities') or [];
}

impl PgIdentityStorage._add_identity(user_id: str, identity: dict[str, any]) -> bool {
    rows = self.store.rows(
        'SELECT doc FROM identity_users WHERE user_id = :u', {'u': user_id}
    );
    if not rows {
        return False;
    }
    try {
        if identity.get('type') == 'sso' and identity.get('provider') {
            self.store.rows(
                """
                INSERT INTO sso_lookups (provider, external_id, user_id)
                VALUES (:p, :e, :u)
                """,
                {
                    'p': identity['provider'],
                    'e': identity.get('external_id', ''),
                    'u': user_id
                }
            );
        } elif identity.get('value_normalized') {
            self.store.rows(
                """
                INSERT INTO identity_lookups (value_normalized, user_id)
                VALUES (:v, :u)
                """,
                {'v': identity['value_normalized'], 'u': user_id}
            );
        }
    } except Exception as e {
        if _pg_unique_violation(e) {
            raise IdentityTakenError();
        }
        raise;
    }
    identities = list(_pg_load_doc(rows[0][0]).get('identities') or []);
    identities.append(identity);
    patch = {'identities': identities, 'updated_at': datetime.now(UTC).isoformat()};
    self.store.rows(
        'UPDATE identity_users SET doc = doc || CAST(:p AS jsonb) WHERE user_id = :u',
        {'u': user_id, 'p': json.dumps(patch, `default=_pg_json_default)}
    );
    return True;
}

impl PgIdentityStorage._set_identity_verified(
    user_id: str, value_normalized: str
) -> bool {
    rows = self.store.rows(
        'SELECT doc FROM identity_users WHERE user_id = :u', {'u': user_id}
    );
    if not rows {
        return False;
    }
    identities = list(_pg_load_doc(rows[0][0]).get('identities') or []);
    changed = False;
    for identity in identities {
        if identity.get('value_normalized') == value_normalized {
            if not identity.get('verified') {
                identity['verified'] = True;
                changed = True;
            }
        }
    }
    if not changed {
        return False;
    }
    patch = {'identities': identities, 'updated_at': datetime.now(UTC).isoformat()};
    self.store.rows(
        'UPDATE identity_users SET doc = doc || CAST(:p AS jsonb) WHERE user_id = :u',
        {'u': user_id, 'p': json.dumps(patch, `default=_pg_json_default)}
    );
    return True;
}

impl PgIdentityStorage._remove_sso_identity(user_id: str, platform: str) -> bool {
    rows = self.store.rows(
        'SELECT doc FROM identity_users WHERE user_id = :u', {'u': user_id}
    );
    if not rows {
        return False;
    }
    identities = list(_pg_load_doc(rows[0][0]).get('identities') or []);
    filtered = [
        i
        for i in identities
        if not (i.get('type') == 'sso' and i.get('provider') == platform)
    ];
    if len(filtered) == len(identities) {
        return False;
    }
    patch = {'identities': filtered, 'updated_at': datetime.now(UTC).isoformat()};
    self.store.rows(
        'UPDATE identity_users SET doc = doc || CAST(:p AS jsonb) WHERE user_id = :u',
        {'u': user_id, 'p': json.dumps(patch, `default=_pg_json_default)}
    );
    self.store.rows(
        'DELETE FROM sso_lookups WHERE user_id = :u AND provider = :p',
        {'u': user_id, 'p': platform}
    );
    return True;
}

impl PgIdentityStorage._replace_username(
    user_id: str, identity: dict[str, any]
) -> bool {
    rows = self.store.rows(
        'SELECT doc FROM identity_users WHERE user_id = :u', {'u': user_id}
    );
    if not rows {
        return False;
    }
    identities = list(_pg_load_doc(rows[0][0]).get('identities') or []);
    kept = [
        i
        for i in identities
        if i.get('type') != 'username'
    ];
    old_values = [
        str(i.get('value_normalized') or '')
        for i in identities
        if i.get('type') == 'username'
    ];
    try {
        self.store.rows(
            """
            INSERT INTO identity_lookups (value_normalized, user_id)
            VALUES (:v, :u)
            """,
            {'v': identity['value_normalized'], 'u': user_id}
        );
    } except Exception as e {
        if _pg_unique_violation(e) {
            raise IdentityTakenError();
        }
        raise;
    }
    for old in old_values {
        if old and old != identity['value_normalized'] {
            self.store.rows(
                'DELETE FROM identity_lookups WHERE value_normalized = :v AND user_id = :u',
                {'v': old, 'u': user_id}
            );
        }
    }
    kept.insert(0, identity);
    patch = {'identities': kept, 'updated_at': datetime.now(UTC).isoformat()};
    self.store.rows(
        'UPDATE identity_users SET doc = doc || CAST(:p AS jsonb) WHERE user_id = :u',
        {'u': user_id, 'p': json.dumps(patch, `default=_pg_json_default)}
    );
    return True;
}

impl PgIdentityStorage._find_sso_link(
    platform: str, external_id: str
) -> dict[str, any] | None {
    rows = self.store.rows(
        """
        SELECT sl.user_id FROM sso_lookups sl
        JOIN identity_users t ON sl.user_id = t.user_id
        WHERE sl.provider = :p AND sl.external_id = :e
          AND COALESCE(t.doc->>'status', 'active') <> 'disabled'
        """,
        {'p': platform, 'e': external_id}
    );
    return {'user_id': str(rows[0][0])} if rows else None;
}

impl PgIdentityStorage.get_user_by_sso(
    platform: str, external_id: str
) -> dict[str, any] | None {
    rows = self.store.rows(
        """
        SELECT t.doc FROM identity_users t
        JOIN sso_lookups sl ON t.user_id = sl.user_id
        WHERE sl.provider = :p AND sl.external_id = :e
          AND COALESCE(t.doc->>'status', 'active') <> 'disabled'
        """,
        {'p': platform, 'e': external_id}
    );
    return _pg_public(rows[0][0]) if rows else None;
}

impl PgIdentityStorage.list_all_users(limit: int, offset: int) -> list[dict[str, any]] {
    rows = self.store.rows(
        """
        SELECT doc FROM identity_users
        WHERE user_id NOT IN (
            SELECT user_id FROM identity_lookups WHERE value_normalized = :g
        )
        ORDER BY doc->>'created_at' DESC
        LIMIT CAST(:l AS int) OFFSET CAST(:o AS int)
        """,
        {'g': Con.GUEST.value, 'l': str(limit), 'o': str(offset)}
    );
    return [_pg_public(r[0]) for r in rows];
}
