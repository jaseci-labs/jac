import os;
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.scale.sso.github { GithubSSOProvider }
import from jaclang.scale.sso.oauth_session { OAuthSession, OAuthStart, OAuthLogin }

def users -> UserManager {
    return JacRuntime.get_user_manager(JacRuntime.get_base_path_dir() or ".");
}

def oauth_session -> OAuthSession {
    callback = os.environ.get("SSO_HOST", "http://127.0.0.1:8095").rstrip("/")
        + "/jacyac/github/callback";
    return OAuthSession(
        users=users(),
        platform="github",
        provider=GithubSSOProvider(
            client_id=os.environ.get("SSO_GITHUB_CLIENT_ID", ""),
            client_secret=os.environ.get("SSO_GITHUB_CLIENT_SECRET", ""),
            redirect_uri=callback
        )
    );
}

def:pub github_enabled -> bool {
    return bool(
        os.environ.get("SSO_GITHUB_CLIENT_ID", "")
            and os.environ.get("SSO_GITHUB_CLIENT_SECRET", "")
    );
}

def:pub begin_github(
    challenge: str, mode: str = "web", session_token: str = ""
) -> OAuthStart {
    if not github_enabled() {
        return OAuthStart(error="GitHub sign-in is not configured yet.");
    }
    user_id = users().validate_jwt_token(session_token) or "" if session_token else "";
    if session_token and not user_id {
        return OAuthStart(error="Please sign in again before connecting GitHub.");
    }
    return oauth_session().begin(challenge, mode, user_id);
}

def:pub github_callback_mode(state: str) -> str {
    return oauth_session().callback_mode(state);
}

async def:pub finish_github(code: str, state: str, verifier: str) -> OAuthLogin {
    return await oauth_session().finish(code, state, verifier);
}

async def:pub complete_native_github(code: str, state: str) -> str {
    return await oauth_session().complete_native(code, state);
}

def:pub poll_github(poll: str) -> OAuthLogin {
    return oauth_session().poll(poll);
}

def github_id(session_token: str) -> str {
    manager = users();
    user_id = manager.validate_jwt_token(session_token) or "";
    if not user_id {
        return "";
    }
    for account in manager.get_sso_accounts(user_id) {
        if account.get("platform") == "github" {
            return str(account.get("external_id") or "");
        }
    }
    return "";
}
