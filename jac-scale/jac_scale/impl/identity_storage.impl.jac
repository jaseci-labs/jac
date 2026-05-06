"""Shared business logic for IdentityStorage base class.

Concrete public methods live here. They call abstract primitives and
public methods implemented by MongoIdentityStorage / SqliteIdentityStorage.
"""

impl IdentityStorage.hash_password(password: str) -> str {
    return str(
        bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    );
}

impl IdentityStorage.verify_password(password: str, password_hash: str) -> bool {
    return bool(
        bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8'))
    );
}

"""Create a new user with identities and a credential."""
impl IdentityStorage.create_user(
    identities: list[dict[str, Any]],
    credential: dict[str, Any],
    profile: dict[str, Any] | None = None
) -> dict[str, Any] {
    import from jaclang.jac0core.constructs { Root }
    import from jaclang { JacRuntime as Jac }

    # Validate identity types: only username, email allowed; max one of each
    type_counts: dict[str, int] = {};
    for identity in identities {
        id_type = identity.get('type', '');
        if id_type not in {'username','email'} {
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

    # Normalize identities and check uniqueness
    normalized_identities: list[dict[str, Any]] = [];
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

    # Hash credential
    credentials: list[dict[str, Any]] = [];
    if credential.get('type') == 'password' {
        password_hash = IdentityStorage.hash_password(credential['password']);
        credentials.append({'type': 'password', 'password_hash': password_hash});
    }

    # Create Jac root node
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
    self._store_user(user_doc);

    return {'user_id': user_id, 'message': 'User registered successfully'};
}

"""Check if a user exists by user_id."""
impl IdentityStorage.user_exists_by_id(user_id: str) -> bool {
    return self.get_user_by_id(user_id) is not None;
}

"""Authenticate by looking up any identity matching identifier, then checking password."""
impl IdentityStorage.authenticate(
    identifier: str, password: str
) -> dict[str, Any] | None {
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

        # --- LEGACY SHA256 MIGRATION (removable) ---
        if cred.get('algorithm') == 'sha256' {
            if hashlib.sha256(password.encode()).hexdigest() == pw_hash {
                cred['password_hash'] = IdentityStorage.hash_password(password);
                cred.pop('algorithm', None);
                self._update_credentials(user_id, credentials);
                return {
                    'user_id': user_id,
                    'root_id': user['root_id'],
                    'role': user.get('role', 'user')
                };
            }
            continue;
        }
        # --- END LEGACY SHA256 MIGRATION ---
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

"""Set user role."""
impl IdentityStorage.set_user_role(user_id: str, role: str) -> bool {
    return self._update_fields(
        user_id, {'role': role, 'updated_at': datetime.now(UTC).isoformat()}
    );
}

"""Get user role by user_id."""
impl IdentityStorage.get_user_role(user_id: str) -> str | None {
    user = self.get_user_by_id(user_id);
    if not user {
        return None;
    }
    return user.get('role', 'user') or 'user';
}

"""Update password for a user (requires current password)."""
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

"""Get root_id for a user."""
impl IdentityStorage.get_root_id(user_id: str) -> str | None {
    user = self.get_user_by_id(user_id);
    return (user.get('root_id') or None) if user else None;
}

"""Get the username identity for a user (first username type, or first identity value)."""
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

"""Generic field updater."""
impl IdentityStorage.update_user_fields(user_id: str, fields: dict[str, Any]) -> bool {
    fields['updated_at'] = datetime.now(UTC).isoformat();
    return self._update_fields(user_id, fields);
}

"""Link an SSO account by adding an identity with type=sso and provider field."""
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

    if not self._add_identity(user_id, identity_doc) {
        return {'error': 'User not found'};
    }
    return {
        'message': 'SSO account linked successfully',
        'user_id': user_id,
        'platform': platform
    };
}

"""Unlink an SSO account by removing the sso identity matching the provider."""
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

"""Get all SSO identities for a user."""
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
