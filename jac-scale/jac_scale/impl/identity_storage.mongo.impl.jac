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
impl MongoIdentityStorage._store_user(user_doc: dict[str, any]) -> None {
    self.users_col.insert_one(user_doc);
}

"""Find a user by user_id (excludes credentials)."""
impl MongoIdentityStorage.get_user_by_id(user_id: str) -> dict[str, any] | None {
    return self.users_col.find_one({'user_id': user_id}, {'_id': 0, 'credentials': 0});
}

"""Find a user by any identity value (excludes credentials)."""
impl MongoIdentityStorage.find_user_by_identity(value: str) -> dict[str, any] | None {
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
impl MongoIdentityStorage._update_fields(user_id: str, fields: dict[str, any]) -> bool {
    result = self.users_col.update_one({'user_id': user_id}, {'$set': fields});
    return result.matched_count > 0;
}

"""Get the credentials array for a user."""
impl MongoIdentityStorage._get_credentials(user_id: str) -> list[dict[str, any]] {
    user = self.users_col.find_one({'user_id': user_id}, {'credentials': 1, '_id': 0});
    if not user {
        return [];
    }
    return user.get('credentials', []);
}

"""Replace the entire credentials array for a user."""
impl MongoIdentityStorage._update_credentials(
    user_id: str, credentials: list[dict[str, any]]
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
impl MongoIdentityStorage._get_identities(user_id: str) -> list[dict[str, any]] {
    user = self.users_col.find_one({'user_id': user_id}, {'identities': 1, '_id': 0});
    if not user {
        return [];
    }
    return user.get('identities', []);
}

"""Append an identity document to a user's identities array."""
impl MongoIdentityStorage._add_identity(
    user_id: str, identity: dict[str, any]
) -> bool {
    try {
        result = self.users_col.update_one(
            {'user_id': user_id},
            {
                '$push': {'identities': identity},
                '$set': {'updated_at': datetime.now(UTC).isoformat()}
            }
        );
    } except DuplicateKeyError {
        raise IdentityTakenError();
    }
    return result.matched_count > 0;
}

"""Mark a single identity (matched by value_normalized) as verified.

Returns True only when the verified flag actually flipped (matches SQLite
semantics). The filter requires the identity to not already be verified, so
matched_count > 0 implies an actual state change.
"""
impl MongoIdentityStorage._set_identity_verified(
    user_id: str, value_normalized: str
) -> bool {
    result = self.users_col.update_one(
        {
            'user_id': user_id,
            'identities': {
                '$elemMatch': {
                    'value_normalized': value_normalized,
                    'verified': {'$ne': True}
                }
            }
        },
        {
            '$set': {
                'identities.$.verified': True,
                'updated_at': datetime.now(UTC).isoformat()
            }
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
) -> dict[str, any] | None {
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
) -> dict[str, any] | None {
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
) -> list[dict[str, any]] {
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
