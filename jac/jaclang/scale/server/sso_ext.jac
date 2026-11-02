import json;
import from urllib.parse { quote }


def resolve_sso_client_redirect(requested: (str | None), configured: str) -> str;


obj SSOExtension(ServerExtension) {
    has sso: (SSOAuth | None) = None;

    def register(server: JacAPIServer);
}


obj ApiKeyExtension(ServerExtension) {
    has manager: (ApiKeyManager | None) = None;

    def api_keys -> ApiKeyManager;
    def register(server: JacAPIServer);
}
