import hashlib;
import logging;
import re;
import secrets;
import from jaclang.server.identity.common_passwords { COMMON_PASSWORDS }
import from jaclang.server.identity.config { auth_settings }
import from jaclang.server.serving.client { request_sync }
import from jaclang.server.settings { IDENTIFIER_KINDS, PASSWORD_CLASSES }

glob logger = logging.getLogger(__name__),
     POLICY_VIOLATION: str = 'POLICY_VIOLATION',
     VERIFY_BEFORE_LOGIN: str = 'verify_before_login',
     CONTAINED_IDENTIFIER_MIN: int = 4,
     BREACH_RANGE_URL: str = 'https://api.pwnedpasswords.com/range/',
     BREACH_TIMEOUT: float = 3.0;

enum Violation {
    IDENTIFIER_REQUIRED = 'IDENTIFIER_REQUIRED',
    IDENTIFIER_NOT_ALLOWED = 'IDENTIFIER_NOT_ALLOWED',
    USERNAME_INVALID = 'USERNAME_INVALID',
    EMAIL_DOMAIN_NOT_ALLOWED = 'EMAIL_DOMAIN_NOT_ALLOWED',
    PASSWORD_TOO_SHORT = 'PASSWORD_TOO_SHORT',
    PASSWORD_TOO_LONG = 'PASSWORD_TOO_LONG',
    PASSWORD_MISSING_CLASS = 'PASSWORD_MISSING_CLASS',
    PASSWORD_COMMON = 'PASSWORD_COMMON',
    PASSWORD_CONTAINS_IDENTIFIER = 'PASSWORD_CONTAINS_IDENTIFIER',
    PASSWORD_BREACHED = 'PASSWORD_BREACHED',
    PASSWORD_REUSED = 'PASSWORD_REUSED'
}

glob VIOLATION_TEXT: dict[Violation, str] = {
         Violation.IDENTIFIER_REQUIRED: 'a required identifier is missing',
         Violation.IDENTIFIER_NOT_ALLOWED: 'this kind of identifier is not accepted',
         Violation.USERNAME_INVALID: 'the username is not valid',
         Violation.EMAIL_DOMAIN_NOT_ALLOWED: 'this email domain is not accepted',
         Violation.PASSWORD_TOO_SHORT: 'the password is too short',
         Violation.PASSWORD_TOO_LONG: 'the password is too long',
         Violation.PASSWORD_MISSING_CLASS: 'the password is missing a required kind of character',
         Violation.PASSWORD_COMMON: 'the password is too common',
         Violation.PASSWORD_CONTAINS_IDENTIFIER: 'the password contains the username or email',
         Violation.PASSWORD_BREACHED: 'the password appears in a known data breach',
         Violation.PASSWORD_REUSED: 'the password was used recently'
     };


def refusal(violations: list[Violation]) -> dict[str, any] {
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


def breached(password: str) -> bool {
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


def check_username(value: str) -> list[Violation] {
    rules = auth_settings().username;
    text = value.strip();
    valid = '@' not in text
        and rules.min_length <= len(text) <= rules.max_length
        and (not rules.pattern or re.fullmatch(rules.pattern, text) is not None);
    return [] if valid else [Violation.USERNAME_INVALID];
}


def check_email(value: str) -> list[Violation] {
    allowed = [
        domain.lower().strip().lstrip('@')
        for domain in auth_settings().email.allowed_domains
    ];
    domain = value.lower().strip().rpartition('@')[2];
    return [Violation.EMAIL_DOMAIN_NOT_ALLOWED]
        if allowed and domain not in allowed
        else [];
}


def check_identity(kind: str, value: str) -> list[Violation] {
    if kind not in IDENTIFIER_KINDS
        or getattr(auth_settings().identifiers, kind) == 'off' {
        return [Violation.IDENTIFIER_NOT_ALLOWED];
    }
    return check_username(value) if kind == 'username' else check_email(value);
}


def check_identifiers(identities: list[dict[str, any]]) -> list[Violation] {
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


def character_classes(password: str) -> set[str] {
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


def minted_password(length: int = 48) -> str {
    while True {
        candidate = secrets.token_urlsafe(length)[:length];
        if character_classes(candidate) == set(PASSWORD_CLASSES) {
            return candidate;
        }
    }
}


def check_password(password: str, identifiers: list[str]) -> list[Violation] {
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


def verify_before_login -> bool {
    return auth_settings().email.verification == 'required';
}


def awaiting_verification(user: dict[str, any]) -> (dict[str, any] | None) {
    for identity in (user.get('identities') or []) {
        if identity.get(VERIFY_BEFORE_LOGIN) and not identity.get('verified') {
            return identity;
        }
    }
    return None;
}


def public_policy -> dict[str, any] {
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
