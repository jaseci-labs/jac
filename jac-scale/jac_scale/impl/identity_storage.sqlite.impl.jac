"""SQLite storage primitives for SqliteIdentityStorage using SQLAlchemy Core.

Uses lookup tables (identity_lookups, sso_lookups) for indexed queries,
avoiding full table scans on the JSON identities column.

Business logic lives in the base IdentityStorage (identity_storage.impl.jac).
"""

impl SqliteIdentityStorage.postinit -> None {
    self._engine = create_engine(f"sqlite:///{self.db_path}", echo=False);
    metadata = MetaData();
    self._table = Table(
        'identity_users',
        metadata,
        Column('user_id', String, primary_key=True),
        Column('status', String, default='active'),
        Column('identities', JSON, default=list),
        Column('credentials', JSON, default=list),
        Column('root_id', String),
        Column('role', String, default='user'),
        Column('requires_password_reset', Integer, default=0),
        Column('created_at', String),
        Column('updated_at', String)
    );
    self._identity_lookups = Table(
        'identity_lookups',
        metadata,
        Column('value_normalized', String, primary_key=True),
        Column(
            'user_id',
            String,
            ForeignKey('identity_users.user_id', ondelete='CASCADE'),
            nullable=False
        )
    );
    self._sso_lookups = Table(
        'sso_lookups',
        metadata,
        Column('provider', String, nullable=False),
        Column('external_id', String, nullable=False),
        Column(
            'user_id',
            String,
            ForeignKey('identity_users.user_id', ondelete='CASCADE'),
            nullable=False
        ),
        PrimaryKeyConstraint('provider', 'external_id')
    );
    self.ensure_indexes();
}

"""Create tables."""
impl SqliteIdentityStorage.ensure_indexes -> None {
    self._table.metadata.create_all(self._engine);
}

"""Convert a row to a dict (excludes credentials)."""
def _row_to_dict(row: Any) -> dict[str, Any] {
    return {
        'user_id': row.user_id,
        'status': row.status,
        'identities': row.identities or [],
        'root_id': row.root_id or None,
        'role': row.role or 'user',
        'requires_password_reset': bool(row.requires_password_reset),
        'created_at': row.created_at,
        'updated_at': row.updated_at
    };
}

"""Insert a user document and sync lookup tables."""
impl SqliteIdentityStorage._store_user(user_doc: dict[str, Any]) -> None {
    user_id = user_doc['user_id'];
    id_rows: list[dict[str, str]] = [];
    sso_rows: list[dict[str, str]] = [];
    for identity in user_doc.get('identities', []) {
        if identity.get('type') == 'sso' and identity.get('provider') {
            sso_rows.append(
                {
                    'provider': identity['provider'],
                    'external_id': identity.get('external_id', ''),
                    'user_id': user_id
                }
            );
        } elif identity.get('value_normalized') {
            id_rows.append(
                {'value_normalized': identity['value_normalized'], 'user_id': user_id}
            );
        }
    }
    with self._engine.begin() as conn {
        conn.execute(self._table.insert().values(**user_doc));
        if id_rows {
            conn.execute(
                self._identity_lookups.insert().prefix_with('OR IGNORE'), id_rows
            );
        }
        if sso_rows {
            conn.execute(self._sso_lookups.insert().prefix_with('OR IGNORE'), sso_rows);
        }
    }
}

"""Find a user by user_id (excludes credentials)."""
impl SqliteIdentityStorage.get_user_by_id(user_id: str) -> dict[str, Any] | None {
    t = self._table;
    with self._engine.connect() as conn {
        row = conn.execute(select(t).where(t.c.user_id == user_id)).first();
        return _row_to_dict(row) if row else None;
    }
}

"""Find a user by any identity value using indexed lookup."""
impl SqliteIdentityStorage.find_user_by_identity(value: str) -> dict[str, Any] | None {
    normalized = value.lower().strip();
    t = self._table;
    lk = self._identity_lookups;
    with self._engine.connect() as conn {
        row = conn.execute(
            select(t).join(lk, t.c.user_id == lk.c.user_id).where(
                lk.c.value_normalized == normalized, t.c.status != 'disabled'
            )
        ).first();
        return _row_to_dict(row) if row else None;
    }
}

"""Check if any active identity with this normalized value exists using indexed lookup."""
impl SqliteIdentityStorage.identity_taken(value: str) -> bool {
    normalized = value.lower().strip();
    t = self._table;
    lk = self._identity_lookups;
    with self._engine.connect() as conn {
        row = conn.execute(
            select(lk.c.value_normalized).join(t, lk.c.user_id == t.c.user_id).where(
                lk.c.value_normalized == normalized, t.c.status != 'disabled'
            )
        ).first();
        return row is not None;
    }
}

"""Delete a user and cascade to lookup tables."""
impl SqliteIdentityStorage.delete_user(user_id: str) -> bool {
    t = self._table;
    with self._engine.begin() as conn {
        # Delete lookups first (in case CASCADE isn't enabled)
        conn.execute(
            delete(self._identity_lookups).where(
                self._identity_lookups.c.user_id == user_id
            )
        );
        conn.execute(
            delete(self._sso_lookups).where(self._sso_lookups.c.user_id == user_id)
        );
        result = conn.execute(delete(t).where(t.c.user_id == user_id));
        return result.rowcount > 0;
    }
}

"""Update fields on a user row."""
impl SqliteIdentityStorage._update_fields(
    user_id: str, fields: dict[str, Any]
) -> bool {
    allowed = {c.name for c in self._table.columns} - {'user_id','created_at','identities','credentials'};
    safe_fields = {
        k: v
        for (k, v) in fields.items()
        if k in allowed
    };
    if not safe_fields {
        return False;
    }
    t = self._table;
    with self._engine.begin() as conn {
        result = conn.execute(
            update(t).where(t.c.user_id == user_id).values(**safe_fields)
        );
        return result.rowcount > 0;
    }
}

"""Get the credentials array for a user."""
impl SqliteIdentityStorage._get_credentials(user_id: str) -> list[dict[str, Any]] {
    t = self._table;
    with self._engine.connect() as conn {
        row = conn.execute(
            select(t.c.credentials).where(t.c.user_id == user_id)
        ).first();
        return (row[0] or []) if row else [];
    }
}

"""Replace the entire credentials array for a user."""
impl SqliteIdentityStorage._update_credentials(
    user_id: str, credentials: list[dict[str, Any]]
) -> None {
    t = self._table;
    now = datetime.now(UTC).isoformat();
    with self._engine.begin() as conn {
        conn.execute(
            update(t).where(t.c.user_id == user_id).values(
                credentials=credentials, updated_at=now
            )
        );
    }
}

"""Get the identities array for a user."""
impl SqliteIdentityStorage._get_identities(user_id: str) -> list[dict[str, Any]] {
    t = self._table;
    with self._engine.connect() as conn {
        row = conn.execute(
            select(t.c.identities).where(t.c.user_id == user_id)
        ).first();
        return (row[0] or []) if row else [];
    }
}

"""Append an identity document and sync lookup tables."""
impl SqliteIdentityStorage._add_identity(
    user_id: str, identity: dict[str, Any]
) -> bool {
    t = self._table;
    with self._engine.begin() as conn {
        row = conn.execute(
            select(t.c.identities).where(t.c.user_id == user_id)
        ).first();
        if not row {
            return False;
        }
        identities = list(row[0] or []);
        identities.append(identity);
        now = datetime.now(UTC).isoformat();
        conn.execute(
            update(t).where(t.c.user_id == user_id).values(
                identities=identities, updated_at=now
            )
        );
        # Sync lookup tables (OR IGNORE prevents duplicate key errors)
        if identity.get('type') == 'sso' and identity.get('provider') {
            conn.execute(
                self._sso_lookups.insert().prefix_with('OR IGNORE').values(
                    provider=identity['provider'],
                    external_id=identity.get('external_id', ''),
                    user_id=user_id
                )
            );
        } elif identity.get('value_normalized') {
            conn.execute(
                self._identity_lookups.insert().prefix_with('OR IGNORE').values(
                    value_normalized=identity['value_normalized'], user_id=user_id
                )
            );
        }
        return True;
    }
}

"""Remove an SSO identity and sync sso_lookups."""
impl SqliteIdentityStorage._remove_sso_identity(user_id: str, platform: str) -> bool {
    t = self._table;
    sl = self._sso_lookups;
    with self._engine.begin() as conn {
        row = conn.execute(
            select(t.c.identities).where(t.c.user_id == user_id)
        ).first();
        if not row {
            return False;
        }
        identities = list(row[0] or []);
        filtered = [
            i
            for i in identities
            if not (i.get('type') == 'sso' and i.get('provider') == platform)
        ];
        if len(filtered) == len(identities) {
            return False;
        }
        now = datetime.now(UTC).isoformat();
        conn.execute(
            update(t).where(t.c.user_id == user_id).values(
                identities=filtered, updated_at=now
            )
        );
        # Remove from sso_lookups
        conn.execute(
            delete(sl).where(sl.c.user_id == user_id, sl.c.provider == platform)
        );
        return True;
    }
}

"""Find which active user has a specific SSO link using indexed lookup."""
impl SqliteIdentityStorage._find_sso_link(
    platform: str, external_id: str
) -> dict[str, Any] | None {
    t = self._table;
    sl = self._sso_lookups;
    with self._engine.connect() as conn {
        row = conn.execute(
            select(sl.c.user_id).join(t, sl.c.user_id == t.c.user_id).where(
                sl.c.provider == platform,
                sl.c.external_id == external_id,
                t.c.status != 'disabled'
            )
        ).first();
        return {'user_id': row.user_id} if row else None;
    }
}

"""Find a user by SSO provider and external_id using indexed lookup."""
impl SqliteIdentityStorage.get_user_by_sso(
    platform: str, external_id: str
) -> dict[str, Any] | None {
    t = self._table;
    sl = self._sso_lookups;
    with self._engine.connect() as conn {
        row = conn.execute(
            select(t).join(sl, t.c.user_id == sl.c.user_id).where(
                sl.c.provider == platform,
                sl.c.external_id == external_id,
                t.c.status != 'disabled'
            )
        ).first();
        return _row_to_dict(row) if row else None;
    }
}

"""List user documents excluding guest users and credentials."""
impl SqliteIdentityStorage.list_all_users(
    limit: int, offset: int
) -> list[dict[str, Any]] {
    t = self._table;
    lk = self._identity_lookups;
    with self._engine.connect() as conn {
        # Exclude guest users via lookup table
        guest_subq = select(lk.c.user_id).where(
            lk.c.value_normalized == Con.GUEST.value
        );
        rows = conn.execute(
            select(t).where(t.c.user_id.not_in(guest_subq)).order_by(
                t.c.created_at.desc()
            ).limit(
                limit
            ).offset(
                offset
            )
        ).fetchall();
        return [_row_to_dict(row) for row in rows];
    }
}
