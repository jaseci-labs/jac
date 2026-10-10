def _totp_credentials(
    credentials: list[dict[str, any]], status: str = ''
) -> list[dict[str, any]] {
    return [
        c
        for c in credentials
        if c.get('type') == TOTP_CREDENTIAL
            and (not status or c.get('status') == status)
    ];
}


def _factor_view(credential: dict[str, any]) -> dict[str, any] {
    return {
        'id': str(credential.get('id') or ''),
        'type': TOTP_CREDENTIAL,
        'status': str(credential.get('status') or FACTOR_UNVERIFIED),
        'created_at': credential.get('created_at'),
        'verified_at': credential.get('verified_at')
    };
}


def _refused(code: str) -> dict[str, any] {
    return {'ok': False, 'code': code};
}


def _limited(retry: int) -> dict[str, any] {
    return {'ok': False, 'code': 'RATE_LIMITED', 'retry_after': retry};
}


def _claim_attempt(user_id: str) -> int {
    settings = auth_settings();
    retry = consume_limit(
        ATTEMPT_SCOPE,
        user_id,
        max(1, int(settings.second_factor.attempts)),
        max(1, int(settings.second_factor.lockout_seconds))
    );
    if retry < 0 {
        raise SecondFactorUnavailable();
    }
    return retry;
}


def _first_use(kind: str, subject: str, seconds: int) -> bool {
    db = shared_store();
    if db is None {
        raise SecondFactorUnavailable();
    }
    key = 'second-factor-used:'
        + hashlib.sha256((kind + ':' + subject).encode('utf-8')).hexdigest();
    try {
        rows = db.rows(
            """
            INSERT INTO kv_state (key, value, expires_at)
            VALUES (:k, '1', now() + make_interval(secs => CAST(:ttl AS float8)))
            ON CONFLICT (key) DO NOTHING
            RETURNING key
            """,
            {'k': key, 'ttl': seconds}
        );
    } except Exception as error {
        logger.error(f"second factor replay ledger failed: {error}");
        raise SecondFactorUnavailable() from error;
    }
    return bool(rows);
}


def _matching_factor(
    credentials: list[dict[str, any]], code: str, status: str, factor_id: str = ''
) -> (tuple[str, int] | None) {
    matched: (tuple[str, int] | None) = None;
    for credential in _totp_credentials(credentials, status) {
        candidate = str(credential.get('id') or '');
        if factor_id and candidate != factor_id {
            continue;
        }
        step = matching_step(str(credential.get('secret') or ''), code);
        if step is not None and matched is None {
            matched = (candidate, step);
        }
    }
    return matched;
}


def _recovery_hash(recovery_code: str) -> str {
    text = ''.join(
        [
            ch
            for ch in recovery_code.lower()
            if ch.isalnum()
        ]
    );
    return hashlib.sha256(text.encode('utf-8')).hexdigest();
}


def _new_recovery_codes -> list[str] {
    codes: list[str] = [];
    for index in range(RECOVERY_CODE_COUNT) {
        raw = ''.join(
            [
                secrets.choice(RECOVERY_CODE_ALPHABET)
                for position in range(RECOVERY_CODE_LENGTH)
            ]
        );
        codes.append('-'.join([raw[i:i + 4] for i in range(0, len(raw), 4)]));
    }
    return codes;
}


def _consume_recovery_code(
    storage: IdentityStorage,
    user_id: str,
    credentials: list[dict[str, any]],
    recovery_code: str
) -> bool {
    if not isinstance(recovery_code, str)
        or not recovery_code
        or len(recovery_code) > 64 {
        return False;
    }
    presented = _recovery_hash(recovery_code);
    hit = '';
    for credential in credentials {
        if credential.get('type') != RECOVERY_CREDENTIAL {
            continue;
        }
        for stored in (credential.get('code_hashes') or []) {
            if hmac.compare_digest(
                str(stored).encode('ascii'), presented.encode('ascii')
            ) {
                hit = str(stored);
            }
        }
    }
    if not hit {
        return False;
    }
    if not _first_use('recovery', user_id + ':' + hit, USED_RECOVERY_SECONDS) {
        return False;
    }
    for credential in credentials {
        if credential.get('type') == RECOVERY_CREDENTIAL {
            credential['code_hashes'] = [
                h
                for h in (credential.get('code_hashes') or [])
                if str(h) != hit
            ];
        }
    }
    storage._update_credentials(user_id, credentials);
    return True;
}


def _verified_proof(
    storage: IdentityStorage, user_id: str, code: str, recovery_code: str
) -> (dict[str, any] | None) {
    credentials = storage._get_credentials(user_id);
    if not _totp_credentials(credentials, FACTOR_VERIFIED) {
        return None;
    }
    if code {
        matched = _matching_factor(credentials, code, FACTOR_VERIFIED);
        if matched is None {
            return None;
        }
        if not _first_use(
            'totp', matched[0] + ':' + str(matched[1]), USED_CODE_SECONDS
        ) {
            return None;
        }
        return {'ok': True, 'method': METHOD_TOTP, 'factor_id': matched[0]};
    }
    if recovery_code
        and _consume_recovery_code(storage, user_id, credentials, recovery_code) {
        return {'ok': True, 'method': METHOD_RECOVERY, 'factor_id': ''};
    }
    return None;
}


impl SecondFactorManager.factors(user_id: str) -> list[dict[str, any]] {
    return [
        _factor_view(c)
        for c in _totp_credentials(self.storage._get_credentials(user_id))
    ];
}

impl SecondFactorManager.required_for(user_id: str) -> bool {
    return bool(
        _totp_credentials(self.storage._get_credentials(user_id), FACTOR_VERIFIED)
    );
}

impl SecondFactorManager.enroll(
    user_id: str, password: str, code: str, recovery_code: str, account: str
) -> dict[str, any] {
    retry = _claim_attempt(user_id);
    if retry > 0 {
        return _limited(retry);
    }
    if not self.storage.holds_password(user_id, password) {
        return _refused('INVALID_PASSWORD');
    }
    if self.required_for(user_id)
        and _verified_proof(self.storage, user_id, code, recovery_code) is None {
        return _refused('INVALID_CODE');
    }
    refund_limit(ATTEMPT_SCOPE, user_id);
    credentials = self.storage._get_credentials(user_id);
    if len(_totp_credentials(credentials, FACTOR_VERIFIED)) >= MAX_VERIFIED_FACTORS {
        return _refused('FACTOR_LIMIT');
    }
    kept = [
        c
        for c in credentials
        if not (c.get('type') == TOTP_CREDENTIAL and c.get('status') != FACTOR_VERIFIED)
    ];
    secret = new_totp_secret();
    factor_id = uuid.uuid4().hex;
    kept.append(
        {
            'type': TOTP_CREDENTIAL,
            'id': factor_id,
            'secret': secret,
            'status': FACTOR_UNVERIFIED,
            'created_at': datetime.now(UTC).isoformat(),
            'verified_at': None
        }
    );
    self.storage._update_credentials(user_id, kept);
    issuer = str(auth_settings().second_factor.issuer or '').strip() or DEFAULT_ISSUER;
    return {
        'ok': True,
        'factor_id': factor_id,
        'secret': secret,
        'otpauth_uri': provisioning_uri(secret, account or user_id, issuer)
    };
}

impl SecondFactorManager.confirm(
    user_id: str, factor_id: str, code: str
) -> dict[str, any] {
    if not factor_id {
        return _refused('NOT_FOUND');
    }
    retry = _claim_attempt(user_id);
    if retry > 0 {
        return _limited(retry);
    }
    credentials = self.storage._get_credentials(user_id);
    matched = _matching_factor(credentials, code, '', factor_id);
    if matched is None {
        return _refused('INVALID_CODE');
    }
    if not _first_use('totp', matched[0] + ':' + str(matched[1]), USED_CODE_SECONDS) {
        return _refused('INVALID_CODE');
    }
    refund_limit(ATTEMPT_SCOPE, user_id);
    credentials = self.storage._get_credentials(user_id);
    first = not _totp_credentials(credentials, FACTOR_VERIFIED);
    activated = False;
    for credential in _totp_credentials(credentials) {
        if credential.get('id') == factor_id
            and credential.get('status') != FACTOR_VERIFIED {
            credential['status'] = FACTOR_VERIFIED;
            credential['verified_at'] = datetime.now(UTC).isoformat();
            activated = True;
        }
    }
    recovery_codes: list[str] = [];
    if activated {
        if first {
            recovery_codes = _new_recovery_codes();
            credentials = [
                c
                for c in credentials
                if c.get('type') != RECOVERY_CREDENTIAL
            ];
            credentials.append(
                {
                    'type': RECOVERY_CREDENTIAL,
                    'code_hashes': [_recovery_hash(c) for c in recovery_codes],
                    'created_at': datetime.now(UTC).isoformat()
                }
            );
        }
        self.storage._update_credentials(user_id, credentials);
    }
    return {
        'ok': True,
        'factor_id': factor_id,
        'activated': activated,
        'recovery_codes': recovery_codes
    };
}

impl SecondFactorManager.prove(
    user_id: str, code: str, recovery_code: str
) -> dict[str, any] {
    retry = _claim_attempt(user_id);
    if retry > 0 {
        return _limited(retry);
    }
    proof = _verified_proof(self.storage, user_id, code, recovery_code);
    if proof is None {
        return _refused('INVALID_CODE');
    }
    refund_limit(ATTEMPT_SCOPE, user_id);
    return proof;
}

impl SecondFactorManager.remove(
    user_id: str, factor_id: str, code: str, recovery_code: str
) -> dict[str, any] {
    targets = [
        c
        for c in _totp_credentials(self.storage._get_credentials(user_id))
        if c.get('id') == factor_id
    ];
    if not targets {
        return _refused('NOT_FOUND');
    }
    if targets[0].get('status') == FACTOR_VERIFIED {
        proof = self.prove(user_id, code, recovery_code);
        if not proof.get('ok') {
            return proof;
        }
    }
    kept = [
        c
        for c in self.storage._get_credentials(user_id)
        if not (c.get('type') == TOTP_CREDENTIAL and c.get('id') == factor_id)
    ];
    if not _totp_credentials(kept, FACTOR_VERIFIED) {
        kept = [
            c
            for c in kept
            if c.get('type') != RECOVERY_CREDENTIAL
        ];
    }
    self.storage._update_credentials(user_id, kept);
    return {'ok': True, 'factor_id': factor_id};
}

impl SecondFactorManager.begin_login(
    user_id: str, method: str = METHOD_PASSWORD
) -> dict[str, any] {
    ttl = max(30, int(auth_settings().second_factor.challenge_ttl_seconds));
    token = AuthTokenStore.instance().create_token(
        user_id, LOGIN_CHALLENGE_PURPOSE, ttl, method
    );
    return {
        'mfa_required': True,
        'challenge_token': token,
        'expires_in': ttl,
        'factors': [
            {'id': f['id'], 'type': f['type']}
            for f in self.factors(user_id)
            if f['status'] == FACTOR_VERIFIED
        ]
    };
}

impl SecondFactorManager.complete_login(
    challenge_token: str, code: str, recovery_code: str
) -> dict[str, any] {
    if not isinstance(challenge_token, str)
        or not challenge_token
        or len(challenge_token) > 128 {
        return _refused('INVALID_CHALLENGE');
    }
    store = AuthTokenStore.instance();
    record = store.peek_token(challenge_token, LOGIN_CHALLENGE_PURPOSE);
    user_id = str(record.get('user_id') or '') if record else '';
    if not user_id {
        return _refused('INVALID_CHALLENGE');
    }
    proof = self.prove(user_id, code, recovery_code);
    if not proof.get('ok') {
        proof['user_id'] = user_id;
        return proof;
    }
    if store.consume_token(challenge_token, LOGIN_CHALLENGE_PURPOSE) is None {
        return _refused('INVALID_CHALLENGE');
    }
    return {
        'ok': True,
        'user_id': user_id,
        'method': proof['method'],
        'first_method': str(record.get('identity_value') or METHOD_PASSWORD)
            if record
            else METHOD_PASSWORD
    };
}
