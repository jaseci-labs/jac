import jwt;
import from datetime { UTC, datetime, timedelta }
import from typing { Any }
import from fastapi { Request, Response }
import from jaclang.runtimelib.server { UserManager }
import from jaclang.runtimelib.transport { TransportResponse, Meta }
import from jac_scale.serve { Platforms, Operations }
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

obj JacScaleUserManager(UserManager) {
    has SUPPORTED_PLATFORMS: dict = {};

    def postinit -> None;
    # JWT methods
    def create_jwt_token(username: str) -> str;
    def validate_jwt_token(token: str) -> (str | None);
    def refresh_jwt_token(token: str) -> (str | None);
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
}
