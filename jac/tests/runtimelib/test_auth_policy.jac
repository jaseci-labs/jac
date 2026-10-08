"""The auth policy layer (issue #9895).

A project declares which identifiers an account needs, how strong a password
must be, whether email must be verified and whether registration is open under
`[serve.auth]`. One module checks every write path, and a policy change never
locks out an account that already exists.
"""

import os;
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from uuid { uuid4 }
import from jaclang.project.config { JacConfig }
import from jaclang.server.endpoints.auth { register_auth_endpoints }
import from jaclang.server.identity.auth_models { LoginRequest, RegisterRequest }
import from jaclang.server.identity.config { configure_identity }
import from jaclang.server.identity.mail { IdentityMailer }
import from jaclang.server.identity.policy {
    Violation,
    check_identifiers,
    check_password,
    check_username,
    public_policy
}
import from jaclang.server.identity.rate_limit { AttemptsExhausted }
import from jaclang.server.identity.second_factor { SecondFactorManager }
import from jaclang.server.identity.user_manager { SecondFactorRequired, UserManager }
import from jaclang.server.server { EndpointHost }
import from jaclang.server.serving.app { transport_to_response }
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.endpoint { JEndPoint }
import from jaclang.server.settings {
    AuthSettings,
    EmailSettings,
    IdentifierSettings,
    LockoutSettings,
    PasswordSettings,
    ServeConfigError,
    ServeSettings
}


"""A mail transport that records what it was asked to send."""
obj RecordingEmailer {
    has sent: list[dict[str, str]] = [];

    def is_ready -> bool {
        return True;
    }

    def send_email(
        to_addr: str,
        subject: str,
        body_text: str,
        body_html: (str | None) = None,
        from_addr: (str | None) = None
    ) -> bool {
        self.sent.append({'to': to_addr, 'subject': subject, 'body': body_text});
        return True;
    }
}


"""The smallest host the auth endpoints register against."""
obj Host(EndpointHost) {
    has users: UserManager,
        emailer: any = None,
        routes: dict[str, any] = {};

    def add_endpoint(ep: JEndPoint) {
        self.routes[ep.path] = ep.callback;
    }

    def identity -> UserManager {
        return self.users;
    }

    def mailer -> IdentityMailer {
        return IdentityMailer(emailer=self.emailer);
    }
}


def unique(stem: str) -> str {
    return stem + uuid4().hex[:10];
}


def codes(found: list[Violation]) -> list[str] {
    return [v.value for v in found];
}


def register_body(identities: dict[str, str], password: str) -> RegisterRequest {
    return RegisterRequest.from_dict(
        {
            'identities': [{'type': k, 'value': v} for (k, v) in identities.items()],
            'credential': {'type': 'password', 'password': password}
        }
    );
}


def login_body(kind: str, value: str, password: str) -> LoginRequest {
    return LoginRequest.from_dict(
        {
            'identity': {'type': kind, 'value': value},
            'credential': {'type': 'password', 'password': password}
        }
    );
}


test "auth settings load nested tables and env, and name moved or unknown keys" {
    loaded = AuthSettings.from_table(
        {
            'token_ttl_days': 3,
            'identifiers': {'username': 'off', 'email': 'required'},
            'password': {'min_length': 12, 'require': ['digit'], 'hash_cost': 99}
        }
    );
    assert loaded.token_ttl_days == 3;
    assert loaded.identifiers.username == 'off';
    assert loaded.identifiers.login_identifiers() == ['email'];
    assert loaded.password.min_length == 12 and loaded.password.require == ['digit'];
    assert loaded.password.hash_cost == 17;
    assert AuthSettings.from_table({}).password.min_length == 8;
    assert AuthSettings.from_table({}).identifiers.username == 'required';

    with patch.dict(
        os.environ,
        {
            'JAC_SERVE_AUTH_PASSWORD_MIN_LENGTH': '20',
            'JAC_SERVE_AUTH_SECOND_FACTOR_ISSUER': 'Acme',
            'JAC_SERVE_AUTH_SESSION_COOKIE': 'true'
        }
    ) {
        from_env = AuthSettings.from_table({'password': {'min_length': 12}});
        assert from_env.password.min_length == 20;
        assert from_env.second_factor.issuer == 'Acme';
        assert from_env.session_cookie;
    }

    for (table, needle) in [
        ({'password_hash_cost': 12}, '[serve.auth.password] hash_cost'),
        ({'registration_challenge': True}, '[serve.auth.registration] challenge'),
        ({'pasword': {}}, "has no key 'pasword'"),
        ({'password': {'min_lenght': 9}}, "has no key 'min_lenght'"),
        ({'password': {'min_length': 'long'}}, 'must be an integer'),
        ({'password': {'reject_common': 1}}, 'must be true or false'),
        ({'identifiers': 'email'}, 'must be a table')
    ] {
        try {
            AuthSettings.from_table(table);
            assert False , f"{table} was accepted";
        } except ServeConfigError as refused {
            assert needle in str(refused) , str(refused);
        }
    }
}


test "startup validation names each contradiction in the policy" {
    assert AuthSettings().problems() == [];
    assert AuthSettings(
        identifiers=IdentifierSettings(username='off', email='required')
    ).problems()
        == [];
    for (settings, needle) in [
        (
            AuthSettings(identifiers=IdentifierSettings(username='off', email='off')),
            "both 'off'"
        ),
        (
            AuthSettings(identifiers=IdentifierSettings(username='maybe')),
            "must be 'required', 'optional' or 'off'"
        ),
        (
            AuthSettings(
                identifiers=IdentifierSettings(email='off', login_with=['email'])
            ),
            "which is 'off'"
        ),
        (
            AuthSettings(identifiers=IdentifierSettings(login_with=['email'])),
            'no way to log in'
        ),
        (
            AuthSettings(
                identifiers=IdentifierSettings(email='off'),
                email=EmailSettings(verification='required')
            ),
            "email is 'off'"
        ),
        (AuthSettings(email=EmailSettings(verification='always')), "must be 'none'"),
        (
            AuthSettings(password=PasswordSettings(min_length=20, max_length=10)),
            'min_length <= max_length'
        ),
        (AuthSettings(password=PasswordSettings(require=['emoji'])), "'emoji'"),
        (
            AuthSettings(
                password=PasswordSettings(
                    min_length=2, require=['lower', 'upper', 'digit']
                )
            ),
            'shorter than'
        )
    ] {
        assert any(needle in problem for problem in settings.problems()) , (
            needle,
            settings.problems()
        );
    }
}


test "jac.toml reaches the settings, profiles merge, and [scale.auth] is refused" {
    config = JacConfig.from_toml_str(
        '[serve]\npublic_origin = "https://app.example.test"\n'
        '[serve.auth]\ntoken_ttl_days = 2\n'
        '[serve.auth.email]\nverification = "optional"\nreset_token_ttl_seconds = 600\n'
        '[environments.prod.serve.auth.password]\nmin_length = 16\n'
    );
    settings = ServeSettings.load(config=config);
    assert settings.public_origin == 'https://app.example.test';
    assert settings.auth.token_ttl_days == 2;
    assert settings.auth.email.verification == 'optional';
    assert settings.auth.email.reset_token_ttl_seconds == 600;
    assert settings.auth.password.min_length == 8;
    config.apply_profile('prod');
    merged = ServeSettings.load(config=config).auth;
    assert merged.password.min_length == 16;
    assert merged.token_ttl_days == 2 and merged.email.verification == 'optional';

    stale = JacConfig.from_toml_str(
        '[scale.auth]\nreset_token_ttl_seconds = 600\nsend_verification_burst = 9\n'
    );
    try {
        ServeSettings.load(config=stale);
        assert False , '[scale.auth] was accepted';
    } except ServeConfigError as refused {
        assert '[serve.auth.email] reset_token_ttl_seconds' in str(refused);
        assert 'send_verification_burst was removed' in str(refused);
    }
}


test "the identifier setups accept and refuse the right registrations" {
    username = {'type': 'username', 'value': 'alice'};
    email = {'type': 'email', 'value': 'alice@corp.example'};
    try {
        configure_identity(AuthSettings(), '');
        assert codes(check_identifiers([username])) == [];
        assert codes(check_identifiers([username, email])) == [];
        assert codes(check_identifiers([email])) == ['IDENTIFIER_REQUIRED'];
        assert codes(check_username('victim@corp.example')) == ['USERNAME_INVALID'];

        configure_identity(
            AuthSettings(
                identifiers=IdentifierSettings(username='off', email='required')
            ),
            ''
        );
        assert codes(check_identifiers([email])) == [];
        assert codes(check_identifiers([username]))
            == ['IDENTIFIER_REQUIRED', 'IDENTIFIER_NOT_ALLOWED'];
        assert public_policy()['identifiers']
            == {'username': 'off', 'email': 'required', 'login_with': ['email']};

        configure_identity(
            AuthSettings(
                identifiers=IdentifierSettings(username='required', email='required'),
                email=EmailSettings(allowed_domains=['corp.example'])
            ),
            ''
        );
        assert codes(check_identifiers([username, email])) == [];
        assert codes(check_identifiers([username])) == ['IDENTIFIER_REQUIRED'];
        assert codes(
            check_identifiers([username, {'type': 'email', 'value': 'a@other.example'}])
        )
            == ['EMAIL_DOMAIN_NOT_ALLOWED'];
    } finally {
        configure_identity(AuthSettings(), '');
    }
}


test "the password policy reports every violation at once" {
    try {
        configure_identity(AuthSettings(), '');
        assert codes(check_password('1', [])) == ['PASSWORD_TOO_SHORT'];
        assert codes(check_password('password1', [])) == ['PASSWORD_COMMON'];
        assert codes(check_password('Password1', [])) == ['PASSWORD_COMMON'];
        assert codes(check_password('alice-in-wonder', ['alice']))
            == ['PASSWORD_CONTAINS_IDENTIFIER'];
        assert codes(check_password('carol-in-wonder', ['bob@corp.example'])) == [];
        assert codes(check_password('correct horse battery', ['alice'])) == [];

        configure_identity(
            AuthSettings(
                password=PasswordSettings(
                    min_length=12, require=['upper', 'digit', 'symbol']
                )
            ),
            ''
        );
        assert codes(check_password('qwertyuiop', []))
            == ['PASSWORD_TOO_SHORT', 'PASSWORD_MISSING_CLASS', 'PASSWORD_COMMON'];
        assert codes(check_password('Tr0ub4dor&3-horse', [])) == [];

        configure_identity(
            AuthSettings(password=PasswordSettings(breached_check=True)), ''
        );
        with patch(check_password.__module__ + '.breached', return_value=True) {
            assert codes(check_password('correct horse battery', []))
                == ['PASSWORD_BREACHED'];
        }
    } finally {
        configure_identity(AuthSettings(), '');
    }
}


test "every write path is held to the policy and existing accounts are grandfathered" {
    with TemporaryDirectory() as tmpdir {
        try {
            configure_identity(
                AuthSettings(
                    password=PasswordSettings(
                        min_length=1, reject_common=False, hash_cost=10
                    ),
                    lockout=LockoutSettings(max_attempts=0)
                ),
                tmpdir
            );
            manager = UserManager(base_path=tmpdir);
            old_name = unique('old') + '@corp.example';
            created = manager.create_user_with_identities(
                [{'type': 'username', 'value': old_name}],
                {'type': 'password', 'password': 'pw'}
            );
            assert 'error' in created and created['violations'] == ['USERNAME_INVALID'];
            grandfathered = manager._identity_storage.create_user(
                [{'type': 'username', 'value': old_name}],
                {'type': 'password', 'password': 'pw'}
            );
            old_id = str(grandfathered['user_id']);

            configure_identity(
                AuthSettings(
                    identifiers=IdentifierSettings(
                        username='required', email='required'
                    ),
                    password=PasswordSettings(history=1, hash_cost=10),
                    lockout=LockoutSettings(max_attempts=0)
                ),
                tmpdir
            );
            assert manager.authenticate(old_name, 'pw') is not None;
            assert manager.open_session(old_id).token;

            refused = manager.update_password(old_id, 'pw', 'short');
            assert refused['code'] == 'POLICY_VIOLATION';
            assert refused['violations'] == ['PASSWORD_TOO_SHORT'];
            assert manager.authenticate(old_name, 'pw') is not None;
            assert 'error'
                not in manager.update_password(old_id, 'pw', 'correct horse battery');
            assert manager.update_password(
                old_id, 'correct horse battery', 'correct horse battery'
            )['violations']
                == ['PASSWORD_REUSED'];
            assert manager.reset_password_by_user_id(old_id, 'pw')['violations']
                == ['PASSWORD_TOO_SHORT'];

            name = unique('new');
            missing_email = manager.create_user_with_identities(
                [{'type': 'username', 'value': name}],
                {'type': 'password', 'password': 'correct horse battery'}
            );
            assert missing_email['violations'] == ['IDENTIFIER_REQUIRED'];
            both = manager.create_user_with_identities(
                [
                    {'type': 'username', 'value': name},
                    {'type': 'email', 'value': name + '@corp.example'}
                ],
                {'type': 'password', 'password': '1'}
            );
            assert both['violations'] == ['PASSWORD_TOO_SHORT'];
            assert manager.rename_username(old_id, 'x@y.example')['violations']
                == ['USERNAME_INVALID'];
            assert manager.create_user_as_admin(
                [{'type': 'username', 'value': unique('adm')}], 'changeme'
            )['code']
                == 'POLICY_VIOLATION';

            internal = manager.create_internal_user(unique('svc'), '__no_password__');
            assert 'error' not in internal;
            manager.close();
        } finally {
            configure_identity(AuthSettings(), '');
        }
    }
}


test "login is throttled per source and identity and a success refunds the attempt" {
    with TemporaryDirectory() as tmpdir {
        try {
            configure_identity(
                AuthSettings(
                    password=PasswordSettings(hash_cost=10),
                    lockout=LockoutSettings(max_attempts=3, window_seconds=900)
                ),
                tmpdir
            );
            manager = UserManager(base_path=tmpdir);
            name = unique('carol');
            manager.create_internal_user(name, 'correct horse battery');
            for attempt in range(6) {
                assert manager.authenticate(name, 'correct horse battery', '192.0.2.7')
                    is not None;
            }
            for attempt in range(3) {
                assert manager.authenticate(name, 'wrong', '192.0.2.7') is None;
            }
            try {
                manager.authenticate(name, 'correct horse battery', '192.0.2.7');
                assert False , 'the fourth attempt was not throttled';
            } except AttemptsExhausted as limit {
                assert 0 < limit.retry_after <= 900;
            }
            assert manager.authenticate(name, 'correct horse battery', '192.0.2.8')
                is not None;
            assert manager.authenticate(unique('ghost'), 'x', '192.0.2.7') is None;
            manager.close();
        } finally {
            configure_identity(AuthSettings(), '');
        }
    }
}


test "a session is never minted past a verified second factor" {
    with TemporaryDirectory() as tmpdir {
        try {
            configure_identity(
                AuthSettings(password=PasswordSettings(hash_cost=10)), tmpdir
            );
            manager = UserManager(base_path=tmpdir);
            user_id = str(
                manager.create_internal_user(unique('dave'), 'correct horse battery')[
                    'user_id'
                ]
            );
            assert manager.open_session(user_id).token;
            with patch.object(SecondFactorManager, 'required_for', return_value=True), patch.object(
                SecondFactorManager,
                'begin_login',
                return_value={'mfa_required': True, 'challenge_token': 'c'}
            ) {
                try {
                    manager.create_jwt_token(user_id);
                    assert False , 'an AAL1 token was minted for an MFA account';
                } except SecondFactorRequired {}
                grant = manager.open_session(user_id);
                assert not grant.token and grant.challenge['challenge_token'] == 'c';
                assert manager.create_jwt_token(
                    user_id, assurance={'aal': 'aal2', 'amr': ['pwd', 'otp']}
                );
            }
            manager.close();
        } finally {
            configure_identity(AuthSettings(), '');
        }
    }
}


test "required verification holds the session until the emailed link is used" {
    with TemporaryDirectory() as tmpdir {
        try {
            configure_identity(
                AuthSettings(
                    identifiers=IdentifierSettings(username='off', email='required'),
                    email=EmailSettings(
                        verification='required',
                        verify_url_template='https://app.example.test/v?t={token}'
                    ),
                    password=PasswordSettings(hash_cost=10)
                ),
                tmpdir
            );
            emailer = RecordingEmailer();
            host = Host(users=UserManager(base_path=tmpdir), emailer=emailer);
            register_auth_endpoints(host);
            address = unique('erin') + '@corp.example';

            policy = host.routes['/user/auth-policy'](Request());
            assert policy.data['email'] == {'verification': 'required'};
            assert policy.data['password']['min_length'] == 8;

            weak = host.routes['/user/register'](
                register_body({'email': address}, 'password1'),
                Request(client_host='192.0.2.9')
            );
            assert weak.error.code == 'POLICY_VIOLATION';
            assert weak.error.details == {'violations': ['PASSWORD_COMMON']};
            assert transport_to_response(weak).status_code == 400;

            created = host.routes['/user/register'](
                register_body({'email': address}, 'correct horse battery'),
                Request(client_host='192.0.2.9')
            );
            assert created.ok and created.data['verification_required'];
            assert 'token' not in created.data;
            assert len(emailer.sent) == 1 and emailer.sent[0]['to'] == address;
            link = [
                line
                for line in emailer.sent[0]['body'].splitlines()
                if line.startswith('https://app.example.test/v?t=')
            ][0];

            held = host.routes['/user/login'](
                login_body('email', address, 'correct horse battery'),
                Request(client_host='192.0.2.9')
            );
            assert held.error.code == 'EMAIL_NOT_VERIFIED';
            assert transport_to_response(held).status_code == 403;
            assert len(emailer.sent) == 2;

            assert host.users.set_identity_verified(
                str(created.data['user_id']), address
            );
            opened = host.routes['/user/login'](
                login_body('email', address, 'correct horse battery'),
                Request(client_host='192.0.2.9')
            );
            assert opened.ok and opened.data['token'] , link;

            configure_identity(
                AuthSettings(
                    identifiers=IdentifierSettings(username='off', email='required'),
                    password=PasswordSettings(hash_cost=10)
                ),
                tmpdir
            );
            service = unique('svc');
            host.users.create_internal_user(service, 'correct horse battery');
            assert host.users.authenticate(service, 'correct horse battery')
                is not None;
            closed_to_usernames = host.routes['/user/login'](
                login_body('username', service, 'correct horse battery'),
                Request(client_host='192.0.2.9')
            );
            assert closed_to_usernames.error.code == 'UNAUTHORIZED';
            host.users.close();
        } finally {
            configure_identity(AuthSettings(), '');
        }
    }
}
