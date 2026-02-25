import jwt;
import from datetime { UTC, datetime, timedelta }
import from typing { Any }
import from fastapi { Request, Response }
import from jaclang.runtimelib.server { UserManager }
import from jaclang.runtimelib.transport { TransportResponse, Meta }
import from jac_scale.enums { Platforms, Operations }
import from jac_scale.utils { generate_random_password }
import from jac_scale.config_loader { get_scale_config }
import from jac_scale.sso_provider { SSOProvider, SSOUserInfo }
import from jac_scale.google_sso_provider { GoogleSSOProvider }

# Load configuration
glob _jwt_config = get_scale_config().get_jwt_config(),
     _sso_config = get_scale_config().get_sso_config(),
     JWT_SECRET = _jwt_config['secret'],
     JWT_ALGORITHM = _jwt_config['algorithm'],
     JWT_EXP_DELTA_DAYS = _jwt_config['exp_delta_days'],
     SSO_HOST = _sso_config['host'];

"""User roles enum."""
enum UserRole {
    ADMIN = 'admin',
    USER = 'user',
}

obj JacScaleUserManager(UserManager) {
    has SUPPORTED_PLATFORMS: dict = {},
        ADMIN_USER_ID: str = '00000000-0000-0000-0000-000000000000';

    def postinit -> None;
    # JWT methods
    def create_jwt_token(username: str, include_role: bool = True) -> str;
    def validate_jwt_token(token: str) -> (str | None);
    def refresh_jwt_token(token: str) -> (str | None);
    def get_jwt_claims(token: str) -> (dict | None);
    # SSO methods
    def get_sso(platform: str, operation: str) -> (SSOProvider | None);
    async def sso_initiate(
        platform: str, operation: str
    ) -> (Response | TransportResponse);

    async def sso_callback(
        request: Request, platform: str, operation: str
    ) -> TransportResponse;

    # SSO Account Linking methods
    def link_sso_account(
        user_id: str, platform: str, external_id: str, email: str
    ) -> dict[str, str];

    def unlink_sso_account(user_id: str, platform: str) -> dict[str, str];
    def get_sso_accounts(user_id: str) -> list[dict[str, str]];
    def get_user_by_sso(platform: str, external_id: str) -> (dict[str, str] | None);
    # Override validate_token to use JWT
    def validate_token(token: str) -> (str | None);
    # User role and admin management
    def get_user_role(username: str) -> (str | None);
    def set_user_role(username: str, role: str) -> dict[str, str];
    def is_admin(username: str) -> bool;
    def requires_password_reset(username: str) -> bool;
    def set_requires_password_reset(
        username: str, requires_reset: bool
    ) -> dict[str, str];

    def is_password_required(username: str) -> bool;
    def set_password_required(username: str, required: bool) -> dict[str, str];
    def bootstrap_admin_user -> dict[str, str];
    def list_all_users(limit: int = 100, offset: int = 0) -> list[dict[str, Any]];
    def delete_user(username: str) -> dict[str, str];
    def create_user_as_admin(
        username: str,
        password: str,
        role: str = 'user',
        requires_password_reset: bool = True
    ) -> dict[str, Any];
}
