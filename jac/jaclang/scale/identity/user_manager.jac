import jwt;
import logging;
import from datetime { UTC, datetime, timedelta }
import from fastapi { Request, Response }
import from contextvars { ContextVar }
import from jaclang.runtimelib.server { UserManager }
import from jaclang.runtimelib.transport { TransportResponse, Meta }
import from jaclang.scale.shared.enums { Platforms, Operations }
import from jaclang.scale.shared.utils {
    generate_random_password,
    is_safe_loopback_redirect
}
import from jaclang.scale.config.firebase_env { firebase_project_id_env_hint }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.sso.provider { SSOProvider, SSOUserInfo }
import from jaclang.scale.identity.identity_storage {
    IdentityStorage,
    MongoIdentityStorage,
    SqliteIdentityStorage
}
import from jaclang.jac0core.constant { Constants as Con }

glob _jwt_config = get_scale_config().get_jwt_config(),
     _sso_config = get_scale_config().get_sso_config(),
     JWT_SECRET = _jwt_config['secret'],
     JWT_ALGORITHM = _jwt_config['algorithm'],
     JWT_EXP_DELTA_DAYS = _jwt_config['exp_delta_days'],
     SSO_HOST = _sso_config['host'],
     logger = logging.getLogger(__name__),
     _root_id_request_cache: ContextVar[dict[str, str] | None] = ContextVar(
         '_jaclang_scale_root_id_cache', default=None
     );

enum UserRole { ADMIN = 'admin', SYSTEM = 'system', USER = 'user', }

obj JacScaleUserManager(UserManager) {
    has SUPPORTED_PLATFORMS: dict = {},
        ADMIN_USER_ID: str = '00000000-0000-0000-0000-000000000000',
        _identity_storage: IdentityStorage by postinit;

    def postinit -> None;
    def create_user(username: str, password: str) -> dict[str, any];
    def create_user_with_identities(
        identities: list[dict[str, any]],
        credential: dict[str, any],
        profile: dict[str, any] | None = None
    ) -> dict[str, any];

    def create_internal_user(
        username: str, password: str, role: str = 'user'
    ) -> dict[str, any];

    def authenticate(identifier: str, password: str) -> dict[str, any] | None;
    def find_user_by_identity(value: str) -> dict[str, any] | None;
    def user_exists(user_id: str) -> bool;
    def get_user(user_id: str) -> dict[str, any] | None;
    def get_root_id(user_id: str) -> str | None;
    def update_password(
        user_id: str, current_password: str, new_password: str
    ) -> dict[str, str];

    def reset_password_by_user_id(user_id: str, new_password: str) -> dict[str, str];
    def add_identity(user_id: str, identity: dict[str, any]) -> bool;
    def is_identity_taken(value: str) -> bool;
    def set_identity_verified(user_id: str, value_normalized: str) -> bool;
    def update_profile(
        user_id: str, profile_updates: dict[str, any]
    ) -> dict[str, any];

    def close -> None;
    def create_jwt_token(user_id: str, include_role: bool = True) -> str;
    def validate_jwt_token(token: str) -> str | None;
    def validate_jwt_token_detail(
        token: str | None, check_existence: bool = True
    ) -> dict[str, any];

    def refresh_jwt_token(token: str) -> str | None;
    def get_jwt_claims(token: str) -> dict | None;
    def get_sso(platform: str) -> SSOProvider | None;
    async def sso_initiate(
        platform: str, operation: str, client_callback: str | None = None
    ) -> Response | TransportResponse;

    async def sso_callback(request: Request, platform: str) -> TransportResponse;
    async def firebase_token_auth_with_id_token(id_token: str) -> TransportResponse;
    def _complete_sso_login(
        platform: str, user_info: SSOUserInfo
    ) -> TransportResponse;

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

    def is_password_required(user_id: str) -> bool;
    def bootstrap_admin_user -> dict[str, str];
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
