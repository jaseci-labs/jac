"""MongoDB storage primitives for MongoIdentityStorage.

Each method is a thin wrapper around pymongo operations.
Business logic lives in the base IdentityStorage (identity_storage.impl.jac).
"""

"""Create unique indexes for identity lookups."""
impl MongoIdentityStorage.ensure_indexes -> None {
    self.users_col.create_index('user_id', unique=True);
    self.users_col.create_index(
        'identities.value_normalized', unique=True, sparse=True
    );
    self.users_col.create_index('status');
}

"""Insert a user document into MongoDB."""
impl MongoIdentityStorage._store_user(user_doc: dict[str, Any]) -> None {
    self.users_col.insert_one(user_doc);
}

"""Find a user by user_id (excludes credentials)."""
impl MongoIdentityStorage.get_user_by_id(user_id: str) -> dict[str, Any] | None {
    return self.users_col.find_one({'user_id': user_id}, {'_id': 0, 'credentials': 0});
}

"""Find a user by any identity value (excludes credentials)."""
impl MongoIdentityStorage.find_user_by_identity(value: str) -> dict[str, Any] | None {
    normalized = value.lower().strip();
    return self.users_col.find_one(
        {'identities.value_normalized': normalized, 'status': {'$ne': 'disabled'}},
        {'_id': 0, 'credentials': 0}
    );
}

"""Check if any active identity with this normalized value exists."""
impl MongoIdentityStorage.identity_taken(value: str) -> bool {
    normalized = value.lower().strip();
    return self.users_col.count_documents(
        {'identities.value_normalized': normalized, 'status': {'$ne': 'disabled'}},
        limit=1
    ) > 0;
}

"""Delete a user by user_id."""
impl MongoIdentityStorage.delete_user(user_id: str) -> bool {
    result = self.users_col.delete_one({'user_id': user_id});
    return result.deleted_count > 0;
}

"""Update arbitrary fields on a user document."""
impl MongoIdentityStorage._update_fields(user_id: str, fields: dict[str, Any]) -> bool {
    result = self.users_col.update_one({'user_id': user_id}, {'$set': fields});
    return result.matched_count > 0;
}

"""Get the credentials array for a user."""
impl MongoIdentityStorage._get_credentials(user_id: str) -> list[dict[str, Any]] {
    user = self.users_col.find_one({'user_id': user_id}, {'credentials': 1, '_id': 0});
    if not user {
        return [];
    }
    return user.get('credentials', []);
}

"""Replace the entire credentials array for a user."""
impl MongoIdentityStorage._update_credentials(
    user_id: str, credentials: list[dict[str, Any]]
) -> None {
    self.users_col.update_one(
        {'user_id': user_id},
        {
            '$set': {
                'credentials': credentials,
                'updated_at': datetime.now(UTC).isoformat()
            }
        }
    );
}

"""Get the identities array for a user."""
impl MongoIdentityStorage._get_identities(user_id: str) -> list[dict[str, Any]] {
    user = self.users_col.find_one({'user_id': user_id}, {'identities': 1, '_id': 0});
    if not user {
        return [];
    }
    return user.get('identities', []);
}

"""Append an identity document to a user's identities array."""
impl MongoIdentityStorage._add_identity(
    user_id: str, identity: dict[str, Any]
) -> bool {
    result = self.users_col.update_one(
        {'user_id': user_id},
        {
            '$push': {'identities': identity},
            '$set': {'updated_at': datetime.now(UTC).isoformat()}
        }
    );
    return result.matched_count > 0;
}

"""Remove an SSO identity matching the provider from a user."""
impl MongoIdentityStorage._remove_sso_identity(user_id: str, platform: str) -> bool {
    result = self.users_col.update_one(
        {'user_id': user_id},
        {
            '$pull': {'identities': {'type': 'sso', 'provider': platform}},
            '$set': {'updated_at': datetime.now(UTC).isoformat()}
        }
    );
    return result.modified_count > 0;
}

"""Find which active user (if any) has a specific SSO link. Returns {user_id} or None."""
impl MongoIdentityStorage._find_sso_link(
    platform: str, external_id: str
) -> dict[str, Any] | None {
    return self.users_col.find_one(
        {
            'identities': {
                '$elemMatch': {
                    'type': 'sso',
                    'provider': platform,
                    'external_id': external_id
                }
            },
            'status': {'$ne': 'disabled'}
        },
        {'user_id': 1, '_id': 0}
    );
}

"""Find a user by SSO provider and external_id (excludes credentials, skips disabled)."""
impl MongoIdentityStorage.get_user_by_sso(
    platform: str, external_id: str
) -> dict[str, Any] | None {
    return self.users_col.find_one(
        {
            'identities': {
                '$elemMatch': {
                    'type': 'sso',
                    'provider': platform,
                    'external_id': external_id
                }
            },
            'status': {'$ne': 'disabled'}
        },
        {'_id': 0, 'credentials': 0}
    );
}

"""List user documents excluding guest users and credentials."""
impl MongoIdentityStorage.list_all_users(
    limit: int, offset: int
) -> list[dict[str, Any]] {
    cursor = self.users_col.find(
        {'identities.value_normalized': {'$ne': Con.GUEST.value}},
        {'_id': 0, 'credentials': 0}
    ).sort(
        'created_at', -1
    ).skip(
        offset
    ).limit(
        limit
    );
    return list(cursor);
}

"""Migrate old-schema users (username/password_hash) to identity-based format.
--- LEGACY MIGRATION (removable) ---"""
impl MongoIdentityStorage.migrate_legacy_users -> None {
    migrations_col = self.users_col.database['_migrations'];
    if migrations_col.find_one({'name': 'legacy_user_migration'}) {
        return;
    }

    legacy_query = {'username': {'$exists': True}, 'identities': {'$exists': False}};
    legacy_docs = list(self.users_col.find(legacy_query));
    now = datetime.now(UTC).isoformat();

    # Drop old-schema indexes that conflict with new format
    for idx_name in ['username_1', 'user_id_1', 'token_1'] {
        try {
            self.users_col.drop_index(idx_name);
            logger.info(f"Dropped old index: {idx_name}");
        } except Exception { }
    }

    if not legacy_docs {
        migrations_col.insert_one(
            {'name': 'legacy_user_migration', 'completed_at': now, 'count': 0}
        );
        return;
    }

    logger.info(f"Starting legacy user migration: {len(legacy_docs)} users found");

    # Track normalized values to detect case-collisions (e.g., "User" and "USER" both -> "user")
    seen_normalized: set[str] = set();
    migrated = 0;
    duplicates = 0;
    for doc in legacy_docs {
        username = doc.get('username');
        if not username {
            logger.warning(f"Skipping doc {doc.get('_id')}: missing username");
            continue;
        }

        is_email = '@' in username;
        normalized = username.lower().strip();
        old_hash = doc.get('password_hash', '');
        existing_user_id = doc.get('user_id');
        new_user_id = existing_user_id or str(uuid.uuid4());

        # Handle case-collision: disable duplicate, keep original value for reference
        is_duplicate = normalized in seen_normalized;
        if is_duplicate {
            logger.warning(
                f"Case-collision: '{username}' conflicts with existing '{normalized}', marking as disabled"
            );
            duplicates += 1;
        }
        seen_normalized.add(normalized);

        new_doc: dict[str, Any] = {
            'user_id': new_user_id,
            'status': 'disabled' if is_duplicate else 'active',
            'identities': [
                {
                    'type': 'email' if is_email else 'username',
                    'value_raw': username,
                    'value_normalized': f"__dup_{new_user_id[:8]}_{normalized}"
                        if is_duplicate
                        else normalized,
                    'verified': True
                }
            ],
            'credentials': [
                {'type': 'password', 'password_hash': old_hash, 'algorithm': 'sha256'}
            ]
                if old_hash
                else [],
            'root_id': doc.get('root_id', ''),
            'role': doc.get('role') or 'user',
            'created_at': now,
            'updated_at': now
        };

        if 'requires_password_reset' in doc {
            new_doc['requires_password_reset'] = doc['requires_password_reset'];
        }

        self.users_col.replace_one({'_id': doc['_id']}, new_doc);
        migrated += 1;
    }

    if duplicates {
        logger.warning(f"{duplicates} duplicate(s) found and marked as disabled");
    }

    migrations_col.insert_one(
        {'name': 'legacy_user_migration', 'completed_at': now, 'count': migrated}
    );
    logger.info(
        f"Legacy user migration complete: {migrated}/{len(legacy_docs)} users migrated"
    );
}
