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
     ],
     _PG_ACCOUNT_LOOKUP_TABLES: list[str] = ['identity_lookups', 'sso_lookups'];


def _pg_account_fk_ddl(table: str) -> str {
    return f"""
    DO $$
    BEGIN
        LOCK TABLE {table} IN SHARE ROW EXCLUSIVE MODE;
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conrelid = CAST('{table}' AS regclass)
              AND conname = '{table}_user_id_fkey'
        ) THEN
            DELETE FROM {table} lk
            WHERE NOT EXISTS (
                SELECT 1 FROM identity_users u WHERE u.user_id = lk.user_id
            );
            ALTER TABLE {table}
                ADD CONSTRAINT {table}_user_id_fkey
                FOREIGN KEY (user_id) REFERENCES identity_users (user_id)
                ON DELETE CASCADE;
        END IF;
    END $$
    """;
}


def _pg_json_default(o: object) -> str {
    return str(o);
}


def _pg_sqlstate(e: Exception) -> str {
    for arg in getattr(e, 'args', ()) {
        if isinstance(arg, dict) and arg.get('C') {
            return str(arg['C']);
        }
    }
    return '';
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
    for table in _PG_ACCOUNT_LOOKUP_TABLES {
        self.store.rows(_pg_account_fk_ddl(table), {});
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

impl PgIdentityStorage._user_exists(user_id: str) -> bool {
    return bool(
        self.store.rows(
            'SELECT 1 FROM identity_users WHERE user_id = :u', {'u': user_id}
        )
    );
}

impl PgIdentityStorage._claim_lookup(value_normalized: str, user_id: str) -> bool {
    try {
        rows = self.store.rows(
            """
            INSERT INTO identity_lookups (value_normalized, user_id)
            VALUES (:v, :u)
            ON CONFLICT (value_normalized) DO UPDATE SET user_id = identity_lookups.user_id
            WHERE identity_lookups.user_id = EXCLUDED.user_id
            RETURNING user_id
            """,
            {'v': value_normalized, 'u': user_id}
        );
    } except Exception as e {
        if _pg_sqlstate(e) == '23503' {
            return False;
        }
        raise;
    }
    if not rows {
        raise IdentityTakenError();
    }
    return True;
}

impl PgIdentityStorage._append_identity(
    user_id: str, identity: dict[str, any]
) -> bool {
    rows = self.store.rows(
        """
        UPDATE identity_users
        SET doc = jsonb_set(
            doc,
            '{identities}',
            COALESCE(doc->'identities', CAST('[]' AS jsonb))
                || jsonb_build_array(CAST(:i AS jsonb)),
            true
        ) || CAST(:p AS jsonb)
        WHERE user_id = :u
          AND NOT EXISTS (
            SELECT 1
            FROM jsonb_array_elements(COALESCE(doc->'identities', CAST('[]' AS jsonb))) held
            WHERE held->>'type' = :t AND held->>'value_normalized' = :v
          )
        RETURNING user_id
        """,
        {
            'u': user_id,
            'i': json.dumps(identity, `default=_pg_json_default),
            'p': json.dumps({'updated_at': datetime.now(UTC).isoformat()}),
            't': str(identity.get('type') or ''),
            'v': str(identity.get('value_normalized') or '')
        }
    );
    return bool(rows);
}

impl PgIdentityStorage.delete_user(user_id: str) -> bool {
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
    if identity.get('type') == 'sso' and identity.get('provider') {
        try {
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
        } except Exception as e {
            state = _pg_sqlstate(e);
            if state == '23505' {
                raise IdentityTakenError();
            }
            if state == '23503' {
                return False;
            }
            raise;
        }
    } elif identity.get('value_normalized') {
        if not self._claim_lookup(identity['value_normalized'], user_id) {
            return False;
        }
    }
    if self._append_identity(user_id, identity) {
        return True;
    }
    if not self._user_exists(user_id) {
        return False;
    }
    raise IdentityTakenError();
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
    if not self._claim_lookup(identity['value_normalized'], user_id) {
        return False;
    }
    rows = self.store.rows(
        """
        WITH prev AS (
            SELECT user_id, doc FROM identity_users WHERE user_id = :u FOR UPDATE
        ),
        kept AS (
            SELECT h.held, h.ord
            FROM prev,
                jsonb_array_elements(COALESCE(prev.doc->'identities', CAST('[]' AS jsonb)))
                    WITH ORDINALITY AS h(held, ord)
            WHERE COALESCE(h.held->>'type', '') <> 'username'
        ),
        old_names AS (
            SELECT held->>'value_normalized' AS value_normalized
            FROM prev,
                jsonb_array_elements(COALESCE(prev.doc->'identities', CAST('[]' AS jsonb))) held
            WHERE held->>'type' = 'username'
        ),
        renamed AS (
            UPDATE identity_users t
            SET doc = jsonb_set(
                prev.doc,
                '{identities}',
                jsonb_build_array(CAST(:i AS jsonb)) || COALESCE(
                    (SELECT jsonb_agg(kept.held ORDER BY kept.ord) FROM kept),
                    CAST('[]' AS jsonb)
                ),
                true
            ) || CAST(:p AS jsonb)
            FROM prev
            WHERE t.user_id = prev.user_id
            RETURNING t.user_id
        ),
        freed AS (
            DELETE FROM identity_lookups lk
            USING old_names
            WHERE lk.user_id = :u
              AND lk.value_normalized = old_names.value_normalized
              AND lk.value_normalized <> :v
              AND lk.value_normalized NOT IN (
                SELECT kept.held->>'value_normalized' FROM kept
                WHERE kept.held->>'value_normalized' IS NOT NULL
              )
        )
        SELECT user_id FROM renamed
        """,
        {
            'u': user_id,
            'v': identity['value_normalized'],
            'i': json.dumps(identity, `default=_pg_json_default),
            'p': json.dumps({'updated_at': datetime.now(UTC).isoformat()})
        }
    );
    return bool(rows);
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
