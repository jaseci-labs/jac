import os;
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.scale.sso.github { GithubSSOProvider }
import from jaclang.scale.sso.oauth_session { OAuthSession, OAuthStart, OAuthLogin }

def:protect users -> UserManager;

def oauth_session -> OAuthSession;

def:pub github_enabled -> bool;

def:pub begin_github(
    challenge: str, mode: str = "web", session_token: str = ""
) -> OAuthStart;

def:pub github_callback_mode(state: str) -> str;

async def:pub finish_github(code: str, state: str, verifier: str) -> OAuthLogin;

async def:pub complete_native_github(code: str, state: str) -> str;

def:pub poll_github(poll: str) -> OAuthLogin;

def github_id(session_token: str) -> str;
