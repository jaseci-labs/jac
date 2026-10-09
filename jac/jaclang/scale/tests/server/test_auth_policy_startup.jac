"""Where the scale layer meets the auth policy (issue #9895).

The policy itself is validated by the server settings. These are the points
that only exist once the scale extensions are in play: the mail transport a
verification policy needs, the bootstrap admin password, and the admin portal's
own login and account-creation paths, which must follow the same rules as the
public ones.
"""

import os;
import from tempfile { TemporaryDirectory }
import from unittest.mock { MagicMock, patch }
import from uuid { uuid4 }
import from jaclang.scale.admin.admin_portal { JacAPIServerAdmin }
import from jaclang.scale.server.extensions { AdminExtension, MailExtension }
import from jaclang.server.identity.config { configure_identity }
import from jaclang.server.identity.mail { verification_problems }
import from jaclang.server.identity.policy { check_password, minted_password }
import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.server.server { EndpointHost, ServerExtension }
import from jaclang.server.serving.app { transport_to_response }
import from jaclang.server.serving.endpoint { JEndPoint }
import from jaclang.server.settings {
    AuthSettings,
    EmailSettings,
    LockoutSettings,
    PasswordSettings
}

"""A mail transport that records what it was asked to send."""
obj RecordingEmailer {
    has sent: list[str] = [];

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
        self.sent.append(to_addr);
        return True;
    }
}


"""The host the admin portal is attached to."""
obj Host(EndpointHost) {
    has users: UserManager,
        emailer: any = None;

    def add_endpoint(ep: JEndPoint) {}
    def identity -> UserManager {
        return self.users;
    }
}


class Quiet(ServerExtension) {
    def register(server: any) {}
}


def admin_config(password: str, enabled: bool = True) -> any {
    config = MagicMock();
    config.get_admin_config.return_value = {
        'enabled': enabled,
        'username': 'admin',
        'default_password': password
    };
    return config;
}


test "required verification without a mail transport stops any server" {
    # The check is the server's own, so it also holds for a server that loads
    # no mail extension at all: an extension only offers the transport.
    assert Quiet().mail_transport() is None;
    assert verification_problems('none', None) == [];
    assert verification_problems('optional', None) == [];
    problems = verification_problems('required', None);
    assert len(problems) == 1 and '[scale.emailer]' in problems[0] , problems;
    assert verification_problems('required', RecordingEmailer()) == [];

    assert MailExtension().mail_transport() is None;
    configured = MailExtension(emailer=RecordingEmailer(), resolved=True);
    assert verification_problems('required', configured.mail_transport()) == [];
}


test "a configured admin password is held to the password policy from any source" {
    target = AdminExtension.__module__ + '.get_scale_config';
    try {
        configure_identity(AuthSettings(password=PasswordSettings(hash_cost=10)), '');
        for from_env in ['', 'changeme'] {
            with patch.dict(os.environ, {'JAC_SCALE_ADMIN_PASSWORD': from_env}) {
                with patch(target, return_value=admin_config('changeme')) {
                    problems = AdminExtension().validate(MagicMock());
                    assert len(problems) == 1 and 'PASSWORD_COMMON' in problems[0] , (
                        from_env,
                        problems
                    );
                }
            }
        }
        with patch(target, return_value=admin_config('correct horse battery')) {
            assert AdminExtension().validate(MagicMock()) == [];
        }
        with patch(target, return_value=admin_config('')) {
            assert AdminExtension().validate(MagicMock()) == [];
        }
        with patch(target, return_value=admin_config('changeme', enabled=False)) {
            assert AdminExtension().validate(MagicMock()) == [];
        }

        # What the server and the deploy mint must pass the strictest policy.
        for bounds in [
            PasswordSettings(require=['lower', 'upper', 'digit', 'symbol']),
            PasswordSettings(
                min_length=64, require=['lower', 'upper', 'digit', 'symbol']
            ),
            PasswordSettings(min_length=12, max_length=20, require=['symbol']),
            PasswordSettings(min_length=3, max_length=3, require=['digit', 'symbol'])
        ] {
            configure_identity(AuthSettings(password=bounds), '');
            for attempt in range(30) {
                assert check_password(minted_password(), ['admin']) == [];
                assert check_password(minted_password(bounds), ['admin']) == [];
            }
        }
        configure_identity(AuthSettings(), '');
        assert len(minted_password(PasswordSettings(min_length=64))) == 64;
        assert len(minted_password(PasswordSettings(max_length=20))) == 20;
    } finally {
        configure_identity(AuthSettings(), '');
    }
}


test "the admin portal mails and holds an unverified email like the public paths" {
    with TemporaryDirectory() as tmpdir {
        try {
            configure_identity(
                AuthSettings(
                    email=EmailSettings(verification='required'),
                    password=PasswordSettings(hash_cost=10),
                    lockout=LockoutSettings(max_attempts=0)
                ),
                tmpdir
            );
            manager = UserManager(base_path=tmpdir);
            emailer = RecordingEmailer();
            portal = JacAPIServerAdmin(
                server=Host(users=manager, emailer=emailer), user_manager=manager
            );
            tag = uuid4().hex[:10];
            root_id = str(
                manager.create_internal_user(
                    'root' + tag, 'correct horse battery', 'admin'
                )['user_id']
            );
            bearer = 'Bearer ' + manager.create_jwt_token(root_id);
            name = 'ops' + tag;
            address = name + '@corp.example';

            malformed = portal.admin_create_user(
                username=name,
                password='another horse battery',
                Authorization=bearer,
                email='bad@@corp.example'
            );
            assert malformed.error.code == 'VALIDATION_ERROR' , malformed.error;
            assert manager.find_user_by_identity(name) is None;
            assert emailer.sent == [];

            created = portal.admin_create_user(
                username=name,
                password='another horse battery',
                role='admin',
                Authorization=bearer,
                email=address
            );
            assert created.ok , created.error;
            assert emailer.sent == [address] , (
                'an admin-created email must get its verification link'
            );

            held = portal.admin_login(username=name, password='another horse battery');
            assert held.error.code == 'EMAIL_NOT_VERIFIED';
            assert transport_to_response(held).status_code == 403;
            assert emailer.sent == [address, address];

            assert manager.set_identity_verified(str(created.data['user_id']), address);
            opened = portal.admin_login(
                username=name, password='another horse battery'
            );
            assert opened.ok and opened.data['token'];
            assert portal.admin_login(
                username='root' + tag, password='correct horse battery'
            ).ok;
            manager.close();
        } finally {
            configure_identity(AuthSettings(), '');
        }
    }
}
