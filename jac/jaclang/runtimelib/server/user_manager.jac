"""Manage users and their persistent roots."""
import from jaclang.runtimelib.server.infra { DataStore }
import from jaclang.runtimelib.server.types { JsonValue }

"""Manage users and their persistent roots."""
obj UserManager {
    has session_path: str,
        _users: dict[(str, dict[(str, str)])] = {},
        _tokens: dict[(str, str)] = {},
        _data_store: (DataStore | None) = None;

    def init(session_path: str, data_store: (DataStore | None) = None) -> None;
    def postinit -> None;
    def _load_db -> None;
    def _persist -> None;
    def create_user(username: str, password: str) -> dict[str, str];
    def authenticate(username: str, password: str) -> (dict[(str, str)] | None);
    def validate_token(token: str) -> (str | None);
    def get_root_id(username: str) -> (str | None);
    def get_user(username: str) -> (dict[(str, str)] | None);
    def close -> None;
}

