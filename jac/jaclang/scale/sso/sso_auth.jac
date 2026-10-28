import logging;
import json;
import secrets;
import re;
import from http.cookies { SimpleCookie }

glob logger = logging.getLogger(__name__);


def sso_host -> str;


def configured_platforms -> dict[str, dict[str, str]];


obj SSOAuth {
    has users: UserManager,
        platforms: dict[str, dict[str, str]] = {};

    def postinit;
    def get_sso(platform: str) -> SSOProvider | None;
    async def sso_initiate(
        platform: str, operation: str, client_callback: str | None = None
    ) -> Response | TransportResponse;

    async def sso_callback(request: Request, platform: str) -> TransportResponse;
    async def firebase_token_auth_with_id_token(id_token: str) -> TransportResponse;
    def login_response(
        result: OAuthLogin,
        platform: str,
        failure: str,
        status: int,
        extra: (dict[str, any] | None) = None
    ) -> TransportResponse;

    def _complete_sso_login(
        platform: str, user_info: SSOUserInfo
    ) -> TransportResponse;
}
