import logging;
import from contextvars { ContextVar }
import from datetime { UTC, datetime, timedelta }
import from jaclang.compiler.frontend.constant { Constants as Con }
import from jaclang.server.identity.identity_storage {
    IdentityStorage,
    PgIdentityStorage
}
import from jaclang.server.serving.authcrypt {
    JWTError,
    JWTExpiredError,
    jwt_decode,
    jwt_encode
}
import from jaclang.server.identity.config {
    signing_algorithm,
    signing_secret,
    token_ttl_days
}

glob logger = logging.getLogger(__name__),
     SYSTEM_USER: str = '__system__',
     _root_id_request_cache: ContextVar[dict[str, str] | None] = ContextVar(
         '_jaclang_root_id_cache', `default=None
     );

enum UserRole { ADMIN = 'admin', SYSTEM = 'system', USER = 'user', }

obj UserManager {
    has base_path: str = '',
        provision_unknown_users: bool = False,
        ADMIN_USER_ID: str = '00000000-0000-0000-0000-000000000000',
        _identity_storage: IdentityStorage postinit;

    def postinit -> None;
    def create_user(username: str, password: str) -> dict[str, any];
    def reset_root(identifier: str) -> str | None;
    def create_user_with_identities(
        identities: list[dict[str, any]],
        credential: dict[str, any],
        profile: dict[str, any] | None = None
    ) -> dict[str, any];

    def create_internal_user(
        username: str, password: str, role: str = 'user'
    ) -> dict[str, any];

    def ensure_internal_user(
        username: str, password: str, role: str = 'user'
    ) -> dict[str, any];

    def authenticate(identifier: str, password: str) -> dict[str, any] | None;
    def find_user_by_identity(value: str) -> dict[str, any] | None;
    def user_exists(user_id: str) -> bool;
    def get_user(user_id: str) -> dict[str, any] | None;
    def get_root_id(user_id: str) -> str | None;
    async def aget_root_id(user_id: str) -> str | None;
    def ensure_user_root(user_id: str) -> str | None;
    def update_password(
        user_id: str, current_password: str, new_password: str
    ) -> dict[str, str];

    def reset_password_by_user_id(user_id: str, new_password: str) -> dict[str, str];
    def add_identity(user_id: str, identity: dict[str, any]) -> bool;
    def rename_username(user_id: str, new_username: str) -> dict[str, any];
    def is_identity_taken(value: str) -> bool;
    def set_identity_verified(user_id: str, value_normalized: str) -> bool;
    def update_profile(
        user_id: str, profile_updates: dict[str, any]
    ) -> dict[str, any];

    def update_user_fields(user_id: str, fields: dict[str, any]) -> bool;
    def close -> None;
    def create_jwt_token(user_id: str, include_role: bool = True) -> str;
    def validate_jwt_token(token: str) -> str | None;
    def validate_jwt_token_detail(
        token: str | None, check_existence: bool = True
    ) -> dict[str, any];

    def refresh_jwt_token(token: str) -> str | None;
    def get_jwt_claims(token: str) -> dict | None;
    def link_sso_account(
        user_id: str, platform: str, external_id: str
    ) -> dict[str, str];

    def unlink_sso_account(user_id: str, platform: str) -> dict[str, str];
    def get_sso_accounts(user_id: str) -> list[dict[str, str]];
    def get_user_by_sso(platform: str, external_id: str) -> dict[str, str] | None;
    def validate_token(token: str) -> str | None;
    def get_user_role(user_id: str) -> str | None;
    def set_user_role(user_id: str, role: str) -> dict[str, str];
    def is_admin(user_id: str) -> bool;
    def requires_password_reset(user_id: str) -> bool;
    def set_requires_password_reset(
        user_id: str, requires_reset: bool
    ) -> dict[str, str];

    def expire_legacy_credentials(username: (str | None) = None) -> dict[str, any];
    def is_password_required(user_id: str) -> bool;
    def bootstrap_admin_user(
        admin_username: str = 'admin', default_password: str = 'changeme'
    ) -> dict[str, str];

    def list_all_users(limit: int = 100, offset: int = 0) -> list[dict[str, any]];
    def delete_user(user_id: str) -> dict[str, str];
    def create_user_as_admin(
        username: str,
        password: str,
        role: str = 'user',
        requires_password_reset: bool = True
    ) -> dict[str, any];

    def get_username(user_id: str) -> str | None;
}
