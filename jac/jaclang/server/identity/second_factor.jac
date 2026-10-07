import hashlib;
import hmac;
import logging;
import secrets;
import uuid;
import from datetime { UTC, datetime }
import from jaclang.server.identity.assurance { METHOD_RECOVERY, METHOD_TOTP }
import from jaclang.server.identity.auth_tokens { AuthTokenStore }
import from jaclang.server.identity.config { auth_settings }
import from jaclang.server.identity.identity_storage { IdentityStorage }
import from jaclang.server.identity.rate_limit { consume_limit, refund_limit }
import from jaclang.server.identity.totp {
    matching_step,
    new_totp_secret,
    provisioning_uri
}
import from jaclang.server.shared_store { shared_store }

glob logger = logging.getLogger(__name__),
     TOTP_CREDENTIAL: str = 'totp',
     RECOVERY_CREDENTIAL: str = 'recovery',
     FACTOR_VERIFIED: str = 'verified',
     FACTOR_UNVERIFIED: str = 'unverified',
     MAX_VERIFIED_FACTORS: int = 5,
     RECOVERY_CODE_COUNT: int = 10,
     RECOVERY_CODE_ALPHABET: str = 'abcdefghjkmnpqrstuvwxyz23456789',
     RECOVERY_CODE_LENGTH: int = 16,
     LOGIN_CHALLENGE_PURPOSE: str = 'second-factor-login',
     ATTEMPT_SCOPE: str = 'second-factor-attempt',
     USED_CODE_SECONDS: int = 300,
     USED_RECOVERY_SECONDS: int = 86400,
     DEFAULT_ISSUER: str = 'Jac';

obj SecondFactorUnavailable(Exception) {}

obj SecondFactorManager {
    has storage: IdentityStorage;

    def factors(user_id: str) -> list[dict[str, any]];
    def required_for(user_id: str) -> bool;
    def enroll(
        user_id: str, password: str, code: str, recovery_code: str, account: str
    ) -> dict[str, any];

    def confirm(user_id: str, factor_id: str, code: str) -> dict[str, any];
    def prove(user_id: str, code: str, recovery_code: str) -> dict[str, any];
    def remove(
        user_id: str, factor_id: str, code: str, recovery_code: str
    ) -> dict[str, any];

    def begin_login(user_id: str) -> dict[str, any];
    def complete_login(
        challenge_token: str, code: str, recovery_code: str
    ) -> dict[str, any];
}
