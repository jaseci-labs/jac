"""Startup checks the scale extensions add to the auth policy (issue #9895).

The policy itself is validated by the server settings. Two contradictions only
show up once the scale extensions are in play: a policy that needs verification
mail with no mail transport configured, and a bootstrap admin password that the
password policy would refuse.
"""

import os;
import from unittest.mock { MagicMock, patch }
import from jaclang.scale.server.extensions { AdminExtension, MailExtension }
import from jaclang.server.identity.config { configure_identity }
import from jaclang.server.settings {
    AuthSettings,
    EmailSettings,
    PasswordSettings,
    ServeSettings
}

obj ReadyEmailer {
    def is_ready -> bool {
        return True;
    }
}


def server_with(verification: str) -> any {
    server = MagicMock();
    server.resolved_settings.return_value = ServeSettings(
        auth=AuthSettings(email=EmailSettings(verification=verification))
    );
    return server;
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


test "required verification without a mail transport stops the server" {
    assert MailExtension().validate(server_with('none')) == [];
    assert MailExtension().validate(server_with('optional')) == [];
    problems = MailExtension().validate(server_with('required'));
    assert len(problems) == 1 and '[scale.emailer]' in problems[0] , problems;
    configured = MailExtension(emailer=ReadyEmailer(), resolved=True);
    assert configured.validate(server_with('required')) == [];
}


test "a configured admin password is held to the password policy" {
    target = AdminExtension.__module__ + '.get_scale_config';
    try {
        configure_identity(AuthSettings(password=PasswordSettings(hash_cost=10)), '');
        with patch.dict(os.environ) {
            os.environ.pop('JAC_SCALE_ADMIN_PASSWORD', None);
            with patch(target, return_value=admin_config('changeme')) {
                problems = AdminExtension().validate(MagicMock());
                assert len(problems) == 1
                    and 'PASSWORD_COMMON' in problems[0] , problems;
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
        }
    } finally {
        configure_identity(AuthSettings(), '');
    }
}
