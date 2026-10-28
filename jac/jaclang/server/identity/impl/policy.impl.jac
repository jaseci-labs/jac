impl refusal(violations: list[Violation]) -> dict[str, any] {
    ordered: list[Violation] = [];
    for violation in violations {
        if violation not in ordered {
            ordered.append(violation);
        }
    }
    return {
        'error': 'Rejected by the auth policy: '
            + '; '.join([VIOLATION_TEXT[v] for v in ordered]),
        'code': POLICY_VIOLATION,
        'violations': [v.value for v in ordered]
    };
}

impl breached(password: str) -> bool {
    digest = hashlib.sha1(password.encode('utf-8')).hexdigest().upper();
    try {
        response = request_sync(
            'GET', BREACH_RANGE_URL + digest[:5], timeout=BREACH_TIMEOUT
        );
        if not response.ok() {
            raise RuntimeError(f"HTTP {response.status_code}");
        }
        listed = {
            line.partition(':')[0].strip() for line in response.text().splitlines()
        };
    } except Exception as error {
        logger.warning(f"breached-password lookup failed, allowing: {error}");
        return False;
    }
    return digest[5:] in listed;
}

impl check_username(value: str) -> list[Violation] {
    rules = auth_settings().username;
    text = value.strip();
    valid = '@' not in text
        and rules.min_length <= len(text) <= rules.max_length
        and (not rules.pattern or re.fullmatch(rules.pattern, text) is not None);
    return [] if valid else [Violation.USERNAME_INVALID];
}

impl check_email(value: str) -> list[Violation] {
    allowed = [
        domain.lower().strip().lstrip('@')
        for domain in auth_settings().email.allowed_domains
    ];
    domain = value.lower().strip().rpartition('@')[2];
    return [Violation.EMAIL_DOMAIN_NOT_ALLOWED]
        if allowed and domain not in allowed
        else [];
}

impl check_identity(kind: str, value: str) -> list[Violation] {
    if kind not in IDENTIFIER_KINDS
        or getattr(auth_settings().identifiers, kind) == 'off' {
        return [Violation.IDENTIFIER_NOT_ALLOWED];
    }
    return check_username(value) if kind == 'username' else check_email(value);
}

impl check_identifiers(identities: list[dict[str, any]]) -> list[Violation] {
    modes = auth_settings().identifiers;
    held = {str(identity.get('type') or '') for identity in identities};
    out: list[Violation] = [
        Violation.IDENTIFIER_REQUIRED
        for kind in IDENTIFIER_KINDS
        if getattr(modes, kind) == 'required' and kind not in held
    ];
    for identity in identities {
        out.extend(
            check_identity(
                str(identity.get('type') or ''), str(identity.get('value') or '')
            )
        );
    }
    return out;
}

impl character_classes(password: str) -> set[str] {
    found: set[str] = set();
    for ch in password {
        if ch.islower() {
            found.add('lower');
        } elif ch.isupper() {
            found.add('upper');
        } elif ch.isdigit() {
            found.add('digit');
        } elif not ch.isalnum() and not ch.isspace() {
            found.add('symbol');
        }
    }
    return found;
}

impl minted_password(rules: (PasswordSettings | None) = None) -> str {
    bounds = rules or auth_settings().password;
    length = min(bounds.max_length, max(bounds.min_length, MINTED_LENGTH));
    classes = [
        name
        for name in PASSWORD_CLASSES
        if name in bounds.require
    ]
        + [
            name
            for name in PASSWORD_CLASSES
            if name not in bounds.require
        ];
    everything = ''.join(MINTED_ALPHABET.values());
    chars = [secrets.choice(MINTED_ALPHABET[name]) for name in classes[:length]];
    while len(chars) < length {
        chars.append(secrets.choice(everything));
    }
    secrets.SystemRandom().shuffle(chars);
    return ''.join(chars);
}

impl check_password(password: str, identifiers: list[str]) -> list[Violation] {
    rules = auth_settings().password;
    out: list[Violation] = [];
    if len(password) < rules.min_length {
        out.append(Violation.PASSWORD_TOO_SHORT);
    }
    if len(password) > rules.max_length {
        out.append(Violation.PASSWORD_TOO_LONG);
    }
    if not set(rules.require) <= character_classes(password) {
        out.append(Violation.PASSWORD_MISSING_CLASS);
    }
    lowered = password.lower();
    if rules.reject_common and lowered in COMMON_PASSWORDS {
        out.append(Violation.PASSWORD_COMMON);
    }
    if rules.reject_identifiers {
        for identifier in identifiers {
            local = identifier.lower().strip().partition('@')[0];
            if len(local) >= CONTAINED_IDENTIFIER_MIN and local in lowered {
                out.append(Violation.PASSWORD_CONTAINS_IDENTIFIER);
                break;
            }
        }
    }
    if rules.breached_check and not out and breached(password) {
        out.append(Violation.PASSWORD_BREACHED);
    }
    return out;
}

impl verify_before_login -> bool {
    return auth_settings().email.verification == 'required';
}

impl awaiting_verification(user: dict[str, any]) -> (dict[str, any] | None) {
    for identity in (user.get('identities') or []) {
        if identity.get(VERIFY_BEFORE_LOGIN) and not identity.get('verified') {
            return identity;
        }
    }
    return None;
}

impl public_policy -> dict[str, any] {
    settings = auth_settings();
    return {
        'identifiers': {
            'username': settings.identifiers.username,
            'email': settings.identifiers.email,
            'login_with': settings.identifiers.login_identifiers()
        },
        'username': {
            'min_length': settings.username.min_length,
            'max_length': settings.username.max_length,
            'pattern': settings.username.pattern
        },
        'email': {'verification': settings.email.verification},
        'password': {
            'min_length': settings.password.min_length,
            'max_length': settings.password.max_length,
            'require': list(settings.password.require),
            'reject_common': settings.password.reject_common,
            'reject_identifiers': settings.password.reject_identifiers
        },
        'registration': {
            'enabled': settings.registration.enabled,
            'challenge': settings.registration.challenge
        }
    };
}
