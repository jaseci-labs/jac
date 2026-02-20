"""Generate HMAC-SHA256 signature for webhook payload."""
impl WebhookUtils.generate_signature(payload: bytes, secret: str) -> str {
    return hmac.new(secret.encode('utf-8'), payload, hashlib.sha256).hexdigest();
}

"""Verify HMAC-SHA256 signature for webhook payload."""
impl WebhookUtils.verify_signature(payload: bytes, signature: str, secret: str) -> bool {
    expected_signature = WebhookUtils.generate_signature(payload, secret);
    # Use constant-time comparison to prevent timing attacks
    return hmac.compare_digest(signature.lower(), expected_signature.lower());
}

"""Generate a cryptographically secure API key."""
impl WebhookUtils.generate_api_key -> str {
    return secrets.token_hex(32);
}

"""Create a JWT-wrapped API key token."""
impl WebhookUtils.create_api_key_token(
    api_key_id: str, username: str, name: str, expiry_days: int | None = None
) -> str {
    default_expiry = WEBHOOK_API_KEY_EXPIRY_DAYS;
    payload: dict[str, Any] = {
        'type': 'api_key',
        'api_key_id': api_key_id,
        'sub': username,
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
            'username': payload.get('sub', ''),
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

"""Create a new API key for a user."""
impl ApiKeyManager.create_api_key(
    username: str, name: str, expiry_days: int | None = None
) -> TransportResponse {
    # Generate unique API key ID
    api_key_id = secrets.token_hex(16);
    # Create the JWT-wrapped API key
    api_key = WebhookUtils.create_api_key_token(
        api_key_id=api_key_id, username=username, name=name, expiry_days=expiry_days
    );
    key_created_at: datetime = datetime.now(UTC);
    expires_at: datetime | None = None;
    default_expiry = WEBHOOK_API_KEY_EXPIRY_DAYS;
    if expiry_days is not None and expiry_days > 0 {
        expires_at = key_created_at + timedelta(days=int(expiry_days));
    } elif default_expiry > 0 {
        expires_at = key_created_at + timedelta(days=int(default_expiry));
    }
    # Persist key metadata
    key_doc = {
        '_id': api_key_id,
        'username': username,
        'name': name,
        'created_at': key_created_at.isoformat(),
        'expires_at': expires_at.isoformat() if expires_at else None,
        'revoked': False
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
            'expires_at': expires_at.isoformat() if expires_at else None
        },
        meta=Meta(extra={'http_status': 201})
    );
}

"""List all API keys for a user (metadata only, not the keys)."""
impl ApiKeyManager.list_api_keys(username: str) -> TransportResponse {
    keys: list[dict[str, Any]] = [];
    if self._db is not None {
        cursor = self._db.find(
            self._collection, {'username': username, 'revoked': False}
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
            if doc.get('username') == username and not doc.get('revoked', False) {
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
impl ApiKeyManager.revoke_api_key(username: str, api_key_id: str) -> TransportResponse {
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
    if key_info.get('username') != username {
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

"""Validate an API key and return the associated username."""
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
    return key_info.get('username');
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
        # Key not in store - could be a legacy key
        # Allow it if JWT is valid (handled by validate_api_key)
        return True;
    }
    return not key_info.get('revoked', False);
}
