"""Generate HMAC-SHA256 signature for webhook payload."""
impl WebhookUtils.generate_signature(payload: bytes, secret: str) -> str {
    return hmac.new(secret.encode('utf-8'), payload, hashlib.sha256).hexdigest();
}

"""Verify HMAC-SHA256 signature for webhook payload."""
impl WebhookUtils.verify_signature(
    payload: bytes, signature: str, secret: str
) -> bool {
    expected_signature = WebhookUtils.generate_signature(payload, secret);
    # Use constant-time comparison to prevent timing attacks
    return hmac.compare_digest(signature.lower(), expected_signature.lower());
}

"""Generate a cryptographically secure API key."""
impl WebhookUtils.generate_api_key -> str {
    return secrets.token_hex(32);
}

"""Create a JWT-wrapped API key token.

The `sub` claim carries the stable user_id. The `type` claim is kept as
'api_key' so this token can never be accepted as a user session token.
"""
impl WebhookUtils.create_api_key_token(
    api_key_id: str, user_id: str, name: str, expiry_days: int | None = None
) -> str {
    default_expiry = WEBHOOK_API_KEY_EXPIRY_DAYS;
    payload: dict[str, Any] = {
        'type': 'api_key',
        'api_key_id': api_key_id,
        'sub': user_id,
        'name': name,
        'iat': datetime.now(UTC)
    };
    # Add expiry if specified
    current_time = datetime.now(UTC);
    if expiry_days is not None {
        payload['exp'] = current_time + timedelta(days=int(expiry_days));
    } elif default_expiry > 0 {
        payload['exp'] = current_time + timedelta(days=int(default_expiry));
    }
    # If expiry_days is 0 or negative, no expiry is set (permanent key)
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM);
}

"""Validate an API key token and extract user information."""
impl WebhookUtils.validate_api_key(api_key: str) -> dict[str, str] | None {
    try {
        payload = jwt.decode(api_key, JWT_SECRET, algorithms=[JWT_ALGORITHM]);

        # Verify this is an API key token
        if payload.get('type') != 'api_key' {
            return None;
        }

        return {
            'user_id': payload.get('sub', ''),
            'api_key_id': payload.get('api_key_id', ''),
            'name': payload.get('name', '')
        };
    } except jwt.ExpiredSignatureError {
        return None;
    } except jwt.InvalidTokenError {
        return None;
    }
}

"""Extract signature from request header value."""
impl WebhookUtils.extract_signature(header_value: str) -> str {
    # Handle prefixed signatures like "sha256=abc123..."
    if '=' in header_value {
        parts = header_value.split('=', 1);
        if len(parts) == 2 {
            return parts[1];
        }
    }
    return header_value;
}

"""Run the one-time legacy migration and ensure indexes (MongoDB only)."""
impl ApiKeyManager.postinit -> None {
    if self._db is not None {
        try {
            self._migrate_and_index();
        } except Exception as e {
            logger.warning(f"webhook_api_keys migration/index skipped: {e}");
        }
    } else {
        logger.warning(
            "Webhook API keys are stored in memory (no MongoDB configured). "
            "Keys and revocations are NOT durable: every restart invalidates "
            "all keys. Configure MongoDB for production webhook use."
        );
    }
}

"""Backfill user_id/signing_secret/allowed_walkers and index user_id.

Legacy docs stored the identity under `username` (the value was always the
user_id, just mislabeled). Copy it to `user_id`, backfill the new fields,
and index `user_id`. Safe to run repeatedly.
"""
impl ApiKeyManager._migrate_and_index -> None {
    col = self._db._get_mongo_collection(self._collection);
    col.create_index('user_id');
    for doc in col.find({'user_id': {'$exists': False}}) {
        updates: dict[str, Any] = {'user_id': doc.get('username', '')};
        if doc.get('signing_secret') is None {
            updates['signing_secret'] = secrets.token_hex(32);
        }
        if doc.get('allowed_walkers') is None {
            updates['allowed_walkers'] = [];
        }
        col.update_one({'_id': doc.get('_id')}, {'$set': updates});
    }
}

"""Create a new API key for a user."""
impl ApiKeyManager.create_api_key(
    user_id: str, name: str, expiry_days: int | None = None
) -> TransportResponse {
    # Generate unique API key ID
    api_key_id = secrets.token_hex(16);
    # Create the JWT-wrapped API key
    api_key = WebhookUtils.create_api_key_token(
        api_key_id=api_key_id, user_id=user_id, name=name, expiry_days=expiry_days
    );
    key_created_at: datetime = datetime.now(UTC);
    expires_at: datetime | None = None;
    default_expiry = WEBHOOK_API_KEY_EXPIRY_DAYS;
    if expiry_days is not None and expiry_days > 0 {
        expires_at = key_created_at + timedelta(days=int(expiry_days));
    } elif default_expiry > 0 {
        expires_at = key_created_at + timedelta(days=int(default_expiry));
    }
    # The signing_secret is independent of the api_key and is returned only
    # here, once. The caller shares it out of band and signs request bodies
    # with it; it must never travel in a webhook request. allowed_walkers
    # is reserved for the scoping (H3) work.
    signing_secret = secrets.token_hex(32);
    key_doc = {
        '_id': api_key_id,
        'user_id': user_id,
        'name': name,
        'created_at': key_created_at.isoformat(),
        'expires_at': expires_at.isoformat() if expires_at else None,
        'revoked': False,
        'signing_secret': signing_secret,
        'allowed_walkers': []
    };
    if self._db is not None {
        self._db.insert_one(self._collection, key_doc);
    } else {
        self._inmemory_store[api_key_id] = key_doc;
    }
    return TransportResponse.success(
        data={
            'api_key': api_key,
            'api_key_id': api_key_id,
            'name': name,
            'created_at': key_created_at.isoformat(),
            'expires_at': expires_at.isoformat() if expires_at else None,
            'signing_secret': signing_secret
        },
        meta=Meta(extra={'http_status': 201})
    );
}

"""List all API keys for a user (metadata only, not the keys)."""
impl ApiKeyManager.list_api_keys(user_id: str) -> TransportResponse {
    keys: list[dict[str, Any]] = [];
    if self._db is not None {
        cursor = self._db.find(
            self._collection, {'user_id': user_id, 'revoked': False}
        );
        for doc in cursor {
            keys.append(
                {
                    'api_key_id': doc.get('_id', ''),
                    'name': doc.get('name', ''),
                    'created_at': doc.get('created_at'),
                    'expires_at': doc.get('expires_at'),
                    'active': True
                }
            );
        }
    } else {
        for doc in self._inmemory_store.values() {
            if doc.get('user_id') == user_id and not doc.get('revoked', False) {
                keys.append(
                    {
                        'api_key_id': doc.get('_id', ''),
                        'name': doc.get('name', ''),
                        'created_at': doc.get('created_at'),
                        'expires_at': doc.get('expires_at'),
                        'active': True
                    }
                );
            }
        }
    }
    return TransportResponse.success(
        data={'api_keys': keys}, meta=Meta(extra={'http_status': 200})
    );
}

"""Revoke an API key."""
impl ApiKeyManager.revoke_api_key(user_id: str, api_key_id: str) -> TransportResponse {
    # Check if key exists
    key_info: dict | None = None;
    if self._db is not None {
        key_info = self._db.find_one(self._collection, {'_id': api_key_id});
    } else {
        key_info = self._inmemory_store.get(api_key_id);
    }
    if not key_info {
        return TransportResponse.fail(
            code='NOT_FOUND',
            message=f"API key '{api_key_id}' not found",
            meta=Meta(extra={'http_status': 404})
        );
    }
    # Check if key belongs to user
    if key_info.get('user_id') != user_id {
        return TransportResponse.fail(
            code='FORBIDDEN',
            message='Cannot revoke API key owned by another user',
            meta=Meta(extra={'http_status': 403})
        );
    }
    # Mark as revoked
    if self._db is not None {
        self._db.update_one(
            self._collection, {'_id': api_key_id}, {'$set': {'revoked': True}}
        );
    } else {
        self._inmemory_store[api_key_id]['revoked'] = True;
    }
    return TransportResponse.success(
        data={'message': f"API key '{api_key_id}' has been revoked"},
        meta=Meta(extra={'http_status': 200})
    );
}

"""Validate an API key and return the associated user_id."""
impl ApiKeyManager.validate_api_key(api_key: str) -> str | None {
    # Decode the JWT to get key info
    key_info = WebhookUtils.validate_api_key(api_key);
    if not key_info {
        return None;
    }
    api_key_id = key_info.get('api_key_id', '');
    # Check if key is still active (not revoked) in database
    if not self.is_key_active(api_key_id) {
        return None;
    }
    return key_info.get('user_id');
}

"""Check if an API key ID exists and is not revoked."""
impl ApiKeyManager.is_key_active(api_key_id: str) -> bool {
    key_info: dict | None = None;
    if self._db is not None {
        key_info = self._db.find_one(self._collection, {'_id': api_key_id});
    } else {
        key_info = self._inmemory_store.get(api_key_id);
    }
    if not key_info {
        # Fail closed: a key with no stored record cannot be confirmed
        # active. A signed but unknown api_key_id (or a record lost to a
        # store reset) must not be honored.
        return False;
    }
    return not key_info.get('revoked', False);
}

"""Return the per-key signing secret for a valid api_key, or None.

This secret is independent of the api_key itself and is never sent in a
webhook request, so it is what request bodies are HMAC-signed with.
"""
impl ApiKeyManager.get_signing_secret(api_key: str) -> str | None {
    key_info = WebhookUtils.validate_api_key(api_key);
    if not key_info {
        return None;
    }
    api_key_id = key_info.get('api_key_id', '');
    key_doc: dict | None = None;
    if self._db is not None {
        key_doc = self._db.find_one(self._collection, {'_id': api_key_id});
    } else {
        key_doc = self._inmemory_store.get(api_key_id);
    }
    if not key_doc {
        return None;
    }
    return key_doc.get('signing_secret');
}
