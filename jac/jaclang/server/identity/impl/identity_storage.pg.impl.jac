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
    CREATE TABLE IF NOT EXISTS identity_oauth_grants (
        user_id  text NOT NULL REFERENCES identity_users (user_id) ON DELETE CASCADE,
        platform text NOT NULL,
        doc      jsonb NOT NULL,
        version  bigint NOT NULL DEFAULT 1,
        PRIMARY KEY (user_id, platform)
    )
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_identity_lookups_user
        ON identity_lookups (user_id)
    """
     ];


def _pg_json_default(o: object) -> str;


def _pg_unique_violation(e: Exception) -> bool;


def _pg_foreign_key_violation(e: Exception) -> bool;


def _pg_load_doc(raw: any) -> dict[str, any];


def _pg_public(raw: any) -> dict[str, any];


def _grant_doc(grant: dict[str, any]) -> dict[str, any];


impl PgIdentityStorage.postinit -> None {
    self.ensure_indexes();
}

impl PgIdentityStorage.ensure_indexes -> None {
    for stmt in _PG_IDENTITY_SCHEMA {
        self.store.rows(stmt, {});
    }
}

impl PgIdentityStorage._store_user(user_doc: dict[str, any]) -> None {
    values: list[str] = [];
    providers: list[str] = [];
    external_ids: list[str] = [];
    for identity in user_doc.get('identities', []) {
        if identity.get('type') == 'sso' and identity.get('provider') {
            providers.append(identity['provider']);
            external_ids.append(identity.get('external_id', ''));
        } elif identity.get('value_normalized') {
            values.append(identity['value_normalized']);
        }
    }
    try {
        self.store.rows(
            """
            WITH u AS (
                INSERT INTO identity_users (user_id, doc)
                VALUES (:u, CAST(:d AS jsonb))
                RETURNING user_id
            ), lookups AS (
                INSERT INTO identity_lookups (value_normalized, user_id)
                SELECT DISTINCT t.v, u.user_id
                FROM u, unnest(CAST(:v AS text[])) AS t(v)
            )
            INSERT INTO sso_lookups (provider, external_id, user_id)
            SELECT s.p, s.e, u.user_id
            FROM u, unnest(CAST(:p AS text[]), CAST(:e AS text[])) AS s(p, e)
            """,
            {
                'u': str(user_doc['user_id']),
                'd': json.dumps(user_doc, `default=_pg_json_default),
                'v': values,
                'p': providers,
                'e': external_ids
            }
        );
    } except Exception as e {
        if _pg_unique_violation(e) {
            raise IdentityTakenError();
        }
        raise;
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
        'SELECT 1 FROM identity_lookups WHERE value_normalized = :v', {'v': normalized}
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
    if safe_fields.get('status') == 'disabled'
        and self._end_sessions(user_id, safe_fields) is not None {
        return True;
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

impl PgIdentityStorage._end_sessions(
    user_id: str, patch: dict[str, any], expected: (int | None) = None
) -> int | None {
    current = """
        CASE WHEN doc->'session_epoch' IS NULL THEN 0
             WHEN jsonb_typeof(doc->'session_epoch') = 'number'
                  AND (doc->>'session_epoch') ~ '^[0-9]+$'
             THEN (doc->>'session_epoch')::bigint
             ELSE -1
        END
    """;
    rows = self.store.rows(
        f"""
        UPDATE identity_users
        SET doc = jsonb_set(
            doc || CAST(:p AS jsonb), '{{session_epoch}}', to_jsonb({current} + 1)
        )
        WHERE user_id = :u
          AND {current} >= 0
          AND (CAST(:e AS bigint) IS NULL OR {current} = CAST(:e AS bigint))
        RETURNING (doc->>'session_epoch')::bigint
        """,
        {'u': user_id, 'p': json.dumps(patch, `default=_pg_json_default), 'e': expected}
    );
    return int(rows[0][0]) if rows else None;
}

impl PgIdentityStorage.credential_state(
    user_id: str
) -> tuple[list[dict[str, any]], any] {
    rows = self.store.rows(
        'SELECT doc FROM identity_users WHERE user_id = :u', {'u': user_id}
    );
    if not rows {
        return ([], None);
    }
    doc = _pg_load_doc(rows[0][0]);
    return (
        doc.get('credentials') or [],
        doc['session_epoch'] if 'session_epoch' in doc else 0
    );
}

impl PgIdentityStorage.session_state(user_id: str) -> dict[str, any] | None {
    rows = self.store.rows(
        'SELECT doc FROM identity_users WHERE user_id = :u', {'u': user_id}
    );
    if not rows {
        return None;
    }
    doc = _pg_load_doc(rows[0][0]);
    return {
        'user_id': doc.get('user_id') or user_id,
        'root_id': doc.get('root_id') or None,
        'status': doc.get('status') or 'active',
        'session_epoch': doc['session_epoch'] if 'session_epoch' in doc else 0
    };
}

impl PgIdentityStorage._get_oauth_grants(user_id: str) -> list[dict[str, any]] {
    rows = self.store.rows(
        """
        SELECT doc, version FROM identity_oauth_grants
        WHERE user_id = :u ORDER BY platform
        """,
        {'u': user_id}
    );
    return [{** _pg_load_doc(r[0]), 'version': int(r[1])} for r in rows];
}

impl PgIdentityStorage._put_oauth_grant(user_id: str, grant: dict[str, any]) -> int {
    try {
        rows = self.store.rows(
            """
            INSERT INTO identity_oauth_grants (user_id, platform, doc)
            VALUES (:u, :p, CAST(:d AS jsonb))
            ON CONFLICT (user_id, platform) DO UPDATE
            SET doc = EXCLUDED.doc, version = identity_oauth_grants.version + 1
            RETURNING version
            """,
            {
                'u': user_id,
                'p': str(grant.get('platform') or ''),
                'd': json.dumps(_grant_doc(grant), `default=_pg_json_default)
            }
        );
    } except Exception as e {
        if _pg_foreign_key_violation(e) {
            return 0;
        }
        raise;
    }
    return int(rows[0][0]);
}

impl PgIdentityStorage._swap_oauth_grant(
    user_id: str, grant: dict[str, any], version: int
) -> int {
    rows = self.store.rows(
        """
        UPDATE identity_oauth_grants
        SET doc = CAST(:d AS jsonb), version = version + 1
        WHERE user_id = :u AND platform = :p AND version = CAST(:v AS bigint)
        RETURNING version
        """,
        {
            'u': user_id,
            'p': str(grant.get('platform') or ''),
            'v': str(version),
            'd': json.dumps(_grant_doc(grant), `default=_pg_json_default)
        }
    );
    return int(rows[0][0]) if rows else 0;
}

impl PgIdentityStorage._take_oauth_grant(
    user_id: str, platform: str, version: (int | None) = None
) -> dict[str, any] | None {
    rows = self.store.rows(
        """
        DELETE FROM identity_oauth_grants
        WHERE user_id = :u AND platform = :p
          AND (CAST(:v AS bigint) IS NULL OR version = CAST(:v AS bigint))
        RETURNING doc
        """,
        {'u': user_id, 'p': platform, 'v': None if version is None else str(version)}
    );
    return _pg_load_doc(rows[0][0]) if rows else None;
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
    identities: list[dict[str, any]] = list(
        _pg_load_doc(rows[0][0]).get('identities') or []
    );
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
    identities: list[dict[str, any]] = list(
        _pg_load_doc(rows[0][0]).get('identities') or []
    );
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
    identities: list[dict[str, any]] = list(
        _pg_load_doc(rows[0][0]).get('identities') or []
    );
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
    identities: list[dict[str, any]] = list(
        _pg_load_doc(rows[0][0]).get('identities') or []
    );
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

impl _pg_json_default(o: object) -> str {
    return str(o);
}


impl _pg_foreign_key_violation(e: Exception) -> bool {
    for arg in getattr(e, 'args', ()) {
        if isinstance(arg, dict) and arg.get('C') == '23503' {
            return True;
        }
    }
    return False;
}

impl _pg_unique_violation(e: Exception) -> bool {
    for arg in getattr(e, 'args', ()) {
        if isinstance(arg, dict) and arg.get('C') == '23505' {
            return True;
        }
    }
    return False;
}


impl _pg_load_doc(raw: any) -> dict[str, any] {
    return raw if isinstance(raw, dict) else json.loads(str(raw));
}


impl _pg_public(raw: any) -> dict[str, any] {
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

impl _grant_doc(grant: dict[str, any]) -> dict[str, any] {
    return {
        k: v
        for (k, v) in grant.items()
        if k != 'version'
    };
}
