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


impl WebhookUtils.create_api_key_token(
    api_key_id: str, user_id: str, name: str, expiry_days: int | None = None
) -> str {
    # Read config at call time so secret/expiry rotation does not require
    # a process restart.
    jwt_config = get_scale_config().get_jwt_config();
    default_expiry = int(
        get_scale_config().get_webhook_config()['api_key_expiry_days']
    );
    payload: dict[str, any] = {
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
    return jwt.encode(payload, jwt_config['secret'], algorithm=jwt_config['algorithm']);
}

"""Validate an API key token and extract user information."""
impl WebhookUtils.validate_api_key(api_key: str) -> dict[str, str] | None {
    try {
        jwt_config = get_scale_config().get_jwt_config();
        payload = jwt.decode(
            api_key, jwt_config['secret'], algorithms=[jwt_config['algorithm']]
        );

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

"""Extract the hex signature from a request header value."""
impl WebhookUtils.extract_signature(header_value: str) -> str {
    value = header_value.strip();
    if value.lower().startswith('sha256=') {
        return value[7:];
    }
    return value;
}

"""Ensure indexes (MongoDB only)."""
impl ApiKeyManager.postinit -> None {
    if self._db is not None {
        try {
            self._ensure_indexes();
        } except Exception as e {
            logger.warning(f"webhook_api_keys index setup skipped: {e}");
        }
    } else {
        logger.warning(
            "Webhook API keys are stored in memory (no MongoDB configured). "
            "Keys and revocations are NOT durable: every restart invalidates "
            "all keys. Configure MongoDB for production webhook use."
        );
    }
}

"""Index user_id for the per-user key lookups. Safe to run repeatedly."""
impl ApiKeyManager._ensure_indexes -> None {
    col = self._db._get_mongo_collection(self._collection);
    col.create_index('user_id');
}

"""Create a new API key for a user."""
impl ApiKeyManager.create_api_key(
    user_id: str,
    name: str,
    expiry_days: int | None = None,
    allowed_walkers: list[str] | None = None
) -> TransportResponse {
    # Generate unique API key ID
    api_key_id = secrets.token_hex(16);
    # Create the JWT-wrapped API key
    api_key = WebhookUtils.create_api_key_token(
        api_key_id=api_key_id, user_id=user_id, name=name, expiry_days=expiry_days
    );
    key_created_at: datetime = datetime.now(UTC);
    expires_at: datetime | None = None;
    default_expiry = int(
        get_scale_config().get_webhook_config()['api_key_expiry_days']
    );
    if expiry_days is not None and expiry_days > 0 {
        expires_at = key_created_at + timedelta(days=int(expiry_days));
    } elif default_expiry > 0 {
        expires_at = key_created_at + timedelta(days=int(default_expiry));
    }
    signing_secret = secrets.token_hex(32);
    key_doc = {
        '_id': api_key_id,
        'user_id': user_id,
        'name': name,
        'created_at': key_created_at.isoformat(),
        'expires_at': expires_at.isoformat() if expires_at else None,
        'revoked': False,
        'signing_secret': signing_secret,
        'allowed_walkers': allowed_walkers or []
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
    keys: list[dict[str, any]] = [];
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

"""Look up a stored key document by id (MongoDB or in-memory)."""
impl ApiKeyManager._get_key_doc(api_key_id: str) -> dict | None {
    if self._db is not None {
        return self._db.find_one(self._collection, {'_id': api_key_id});
    }
    return self._inmemory_store.get(api_key_id);
}

"""Resolve a valid, active api_key to its stored document."""
impl ApiKeyManager.resolve_key(api_key: str) -> dict | None {
    key_info = WebhookUtils.validate_api_key(api_key);
    if not key_info {
        return None;
    }
    key_doc = self._get_key_doc(key_info.get('api_key_id', ''));
    if not key_doc or key_doc.get('revoked', False) {
        return None;
    }
    return key_doc;
}

"""Per-key fixed-window rate check. True if the call is allowed."""
impl ApiKeyManager.check_rate_limit(api_key_id: str, limit_per_minute: int) -> bool {
    if limit_per_minute <= 0 {
        return True;
    }
    window_id = int(datetime.now(UTC).timestamp() // 60);
    entry = self._rate_window.get(api_key_id);
    if not entry or entry[0] != window_id {
        self._rate_window[api_key_id] = [window_id, 1];
        return True;
    }
    if entry[1] >= limit_per_minute {
        return False;
    }
    entry[1] += 1;
    return True;
}
