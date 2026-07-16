impl IdentityStorage.hash_password(password: str) -> str {
    rounds = get_scale_config().get_auth_config()['password_hash_rounds'];
    return str(
        bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt(rounds=rounds)).decode(
            'utf-8'
        )
    );
}

impl IdentityStorage.verify_password(password: str, password_hash: str) -> bool {
    try {
        return bool(
            bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8'))
        );
    } except ValueError {
        return False;
    }
}

impl IdentityStorage.create_user(
    identities: list[dict[str, any]],
    credential: dict[str, any],
    profile: dict[str, any] | None = None
) -> dict[str, any] {
    import from jaclang.jac0core.constructs { Root }
    import from jaclang { JacRuntime as Jac }

    type_counts: dict[str, int] = {};
    for identity in identities {
        id_type = identity.get('type', '');
        if id_type not in {'username', 'email'} {
            return {
                'error': f"Invalid identity type: {id_type}. Only 'username' and 'email' are allowed",
                'code': 'VALIDATION_ERROR'
            };
        }
        type_counts[id_type] = type_counts.get(id_type, 0) + 1;
        if type_counts[id_type] > 1 {
            return {
                'error': f"Duplicate identity type: {id_type}. Only one {id_type} is allowed",
                'code': 'VALIDATION_ERROR'
            };
        }
    }

    user_id = str(uuid.uuid4());
    now = datetime.now(UTC).isoformat();

    normalized_identities: list[dict[str, any]] = [];
    for identity in identities {
        id_type = identity.get('type', '');
        raw_value = identity.get('value', '');
        normalized = raw_value.lower().strip();

        if self.identity_taken(normalized) {
            return {
                'error': f"{id_type.capitalize()} is already registered",
                'code': 'IDENTITY_TAKEN'
            };
        }

        is_verified = identity.get('verified', (id_type == 'username'));
        normalized_identities.append(
            {
                'type': id_type,
                'value_raw': raw_value,
                'value_normalized': normalized,
                'verified': is_verified,
                'is_recovery': (id_type == 'email')
            }
        );
    }

    credentials: list[dict[str, any]] = [];
    if credential.get('type') == 'password' {
        password_hash = IdentityStorage.hash_password(credential['password']);
        credentials.append({'type': 'password', 'password_hash': password_hash});
    }

    user_root = Root();
    Jac.save(user_root);
    Jac.commit(user_root);
    root_id = user_root.__jac__.id.hex;

    user_doc = {
        'user_id': user_id,
        'status': 'active',
        'identities': normalized_identities,
        'credentials': credentials,
        'root_id': root_id,
        'role': 'user',
        'profile': profile or {},
        'created_at': now,
        'updated_at': now
    };
    try {
        self._store_user(user_doc);
    } except IdentityTakenError {
        return {'error': "Identity is already registered", 'code': 'IDENTITY_TAKEN'};
    }

    return {'user_id': user_id, 'message': 'User registered successfully'};
}

impl IdentityStorage.user_exists_by_id(user_id: str) -> bool {
    return self.get_user_by_id(user_id) is not None;
}

impl IdentityStorage.ensure_user_by_id(user_id: str) -> str | None {
    import from jaclang.jac0core.constructs { Root }
    import from jaclang { JacRuntime as Jac }

    existing = self.get_user_by_id(user_id);
    if existing {
        return existing.get('root_id');
    }
    # JIT provisioning for federated identity: another trusted process (the
    # microservice gateway or a sibling service sharing the JWT secret) minted
    # a token for this user_id, but this store has never seen it. Materialize
    # a local user record with a fresh local root so the user's graph in THIS
    # service starts empty. No identities/credentials: login stays wherever
    # the user actually registered.
    user_root = Root();
    Jac.save(user_root);
    Jac.commit(user_root);
    root_id = user_root.__jac__.id.hex;
    now = datetime.now(UTC).isoformat();
    try {
        self._store_user(
            {
                'user_id': user_id,
                'status': 'active',
                'identities': [],
                'credentials': [],
                'root_id': root_id,
                'role': 'user',
                'profile': {},
                'created_at': now,
                'updated_at': now
            }
        );
    } except Exception {
        # Lost a concurrent first-access race for this user_id: another
        # request inserted between our check and our insert. The winner's
        # record is authoritative (mongo raises IdentityTakenError, sqlite a
        # raw IntegrityError - both land here); our freshly-minted root
        # becomes a single orphaned empty node. Anything else re-raises.
        winner = self.get_user_by_id(user_id);
        if winner {
            return winner.get('root_id');
        }
        raise;
    }
    return root_id;
}

impl IdentityStorage.authenticate(
    identifier: str, password: str
) -> dict[str, any] | None {
    user = self.find_user_by_identity(identifier);
    if user is None {
        return None;
    }

    user_id = user['user_id'];
    credentials = self._get_credentials(user_id);
    for cred in credentials {
        if cred.get('type') != 'password' {
            continue;
        }
        pw_hash = cred.get('password_hash', '');
        if IdentityStorage.verify_password(password, pw_hash) {
            return {
                'user_id': user_id,
                'root_id': user['root_id'],
                'role': user.get('role', 'user')
            };
        }
    }
    return None;
}

impl IdentityStorage.set_user_role(user_id: str, role: str) -> bool {
    return self._update_fields(
        user_id, {'role': role, 'updated_at': datetime.now(UTC).isoformat()}
    );
}

impl IdentityStorage.get_user_role(user_id: str) -> str | None {
    user = self.get_user_by_id(user_id);
    if not user {
        return None;
    }
    return user.get('role', 'user') or 'user';
}

impl IdentityStorage.update_password(
    user_id: str, current_password: str, new_password: str
) -> dict[str, str] {
    credentials = self._get_credentials(user_id);
    if not credentials {
        return {'error': 'User not found'};
    }

    found = False;
    for cred in credentials {
        if cred.get('type') == 'password'
        and IdentityStorage.verify_password(
            current_password, cred.get('password_hash', '')
        ) {
            found = True;
            break;
        }
    }
    if not found {
        return {'error': 'Current password is incorrect'};
    }

    new_hash = IdentityStorage.hash_password(new_password);
    for cred in credentials {
        if cred.get('type') == 'password' {
            cred['password_hash'] = new_hash;
        }
    }
    self._update_credentials(user_id, credentials);
    return {'user_id': user_id, 'message': 'Password updated successfully'};
}

impl IdentityStorage.reset_password(user_id: str, new_password: str) -> dict[str, str] {
    if not self.user_exists_by_id(user_id) {
        return {'error': 'User not found'};
    }
    credentials = self._get_credentials(user_id);
    new_hash = IdentityStorage.hash_password(new_password);
    password_set = False;
    for cred in credentials {
        if cred.get('type') == 'password' {
            cred['password_hash'] = new_hash;
            password_set = True;
        }
    }
    if not password_set {
        credentials.append({'type': 'password', 'password_hash': new_hash});
    }
    self._update_credentials(user_id, credentials);
    return {'user_id': user_id, 'message': 'Password updated successfully'};
}

impl IdentityStorage.get_root_id(user_id: str) -> str | None {
    user = self.get_user_by_id(user_id);
    return (user.get('root_id') or None) if user else None;
}

impl IdentityStorage.get_username(user_id: str) -> str | None {
    identities = self._get_identities(user_id);
    for identity in identities {
        if identity.get('type') == 'username' {
            return identity.get('value_raw');
        }
    }
    if identities {
        return identities[0].get('value_raw');
    }
    return None;
}

impl IdentityStorage.update_user_fields(user_id: str, fields: dict[str, any]) -> bool {
    fields['updated_at'] = datetime.now(UTC).isoformat();
    return self._update_fields(user_id, fields);
}

impl IdentityStorage.link_sso_account(
    user_id: str, platform: str, external_id: str
) -> dict[str, str] {
    existing = self._find_sso_link(platform, external_id);
    if existing {
        if existing.get('user_id') == user_id {
            return {'message': 'SSO account already linked to this user'};
        }
        return {'error': 'This SSO account is already linked to another user'};
    }

    now = datetime.now(UTC).isoformat();
    identity_doc = {
        'type': 'sso',
        'provider': platform,
        'external_id': external_id,
        'verified': True,
        'linked_at': now
    };

    try {
        added = self._add_identity(user_id, identity_doc);
    } except IdentityTakenError {
        return {'error': 'This SSO account is already linked to another user'};
    }
    if not added {
        return {'error': 'User not found'};
    }
    return {
        'message': 'SSO account linked successfully',
        'user_id': user_id,
        'platform': platform
    };
}

impl IdentityStorage.unlink_sso_account(user_id: str, platform: str) -> dict[str, str] {
    if not self.user_exists_by_id(user_id) {
        return {'error': 'User not found'};
    }
    if not self._remove_sso_identity(user_id, platform) {
        return {'error': 'SSO account not found for this provider'};
    }
    return {
        'message': 'SSO account unlinked successfully',
        'user_id': user_id,
        'platform': platform
    };
}

impl IdentityStorage.get_sso_accounts(user_id: str) -> list[dict[str, str]] {
    identities = self._get_identities(user_id);
    accounts: list[dict[str, str]] = [];
    for identity in identities {
        if identity.get('type') == 'sso' {
            accounts.append(
                {
                    'platform': identity.get('provider', ''),
                    'external_id': identity.get('external_id', ''),
                    'linked_at': identity.get('linked_at', '')
                }
            );
        }
    }
    return accounts;
}
