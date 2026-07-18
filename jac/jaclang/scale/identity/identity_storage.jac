import bcrypt;
import uuid;
import from datetime { datetime, UTC }
import from sqlalchemy {
    create_engine,
    Engine,
    MetaData,
    Table,
    Column,
    String,
    Integer,
    JSON,
    ForeignKey,
    PrimaryKeyConstraint,
    select,
    delete,
    update
}
import from sqlalchemy.exc { IntegrityError, OperationalError }
import from jaclang.scale._optdeps.pymongo { DuplicateKeyError }
import type from pymongo.collection { Collection }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.scale.config.config_loader { get_scale_config }

obj IdentityTakenError(Exception) {}

obj IdentityStorage {
    static def hash_password(password: str) -> str;
    static def verify_password(password: str, password_hash: str) -> bool;
    def _store_user(user_doc: dict[str, any]) -> None;
    def _update_fields(user_id: str, fields: dict[str, any]) -> bool;
    def _get_credentials(user_id: str) -> list[dict[str, any]];
    def _update_credentials(user_id: str, credentials: list[dict[str, any]]) -> None;
    def _get_identities(user_id: str) -> list[dict[str, any]];
    def _add_identity(user_id: str, identity: dict[str, any]) -> bool;
    def _remove_sso_identity(user_id: str, platform: str) -> bool;
    def _find_sso_link(platform: str, external_id: str) -> dict[str, any] | None;
    def _set_identity_verified(user_id: str, value_normalized: str) -> bool;
    def ensure_indexes -> None;
    def get_user_by_id(user_id: str) -> dict[str, any] | None;
    def delete_user(user_id: str) -> bool;
    def find_user_by_identity(value: str) -> dict[str, any] | None;
    def identity_taken(value: str) -> bool;
    def list_all_users(limit: int = 100, offset: int = 0) -> list[dict[str, any]];
    def get_user_by_sso(platform: str, external_id: str) -> dict[str, any] | None;
    def create_user(
        identities: list[dict[str, any]],
        credential: dict[str, any],
        profile: dict[str, any] | None = None
    ) -> dict[str, any];

    def user_exists_by_id(user_id: str) -> bool;
    def ensure_user_by_id(user_id: str) -> str | None;
    def authenticate(identifier: str, password: str) -> dict[str, any] | None;
    def set_user_role(user_id: str, role: str) -> bool;
    def get_user_role(user_id: str) -> str | None;
    def update_password(
        user_id: str, current_password: str, new_password: str
    ) -> dict[str, str];

    def reset_password(user_id: str, new_password: str) -> dict[str, str];
    def get_root_id(user_id: str) -> str | None;
    def get_username(user_id: str) -> str | None;
    def update_user_fields(user_id: str, fields: dict[str, any]) -> bool;
    def link_sso_account(
        user_id: str, platform: str, external_id: str
    ) -> dict[str, str];

    def unlink_sso_account(user_id: str, platform: str) -> dict[str, str];
    def get_sso_accounts(user_id: str) -> list[dict[str, str]];
}

obj MongoIdentityStorage(IdentityStorage) {
    has users_col: Collection[dict[str, any]];

    def _store_user(user_doc: dict[str, any]) -> None;
    def _update_fields(user_id: str, fields: dict[str, any]) -> bool;
    def _get_credentials(user_id: str) -> list[dict[str, any]];
    def _update_credentials(user_id: str, credentials: list[dict[str, any]]) -> None;
    def _get_identities(user_id: str) -> list[dict[str, any]];
    def _add_identity(user_id: str, identity: dict[str, any]) -> bool;
    def _remove_sso_identity(user_id: str, platform: str) -> bool;
    def _find_sso_link(platform: str, external_id: str) -> dict[str, any] | None;
    def _set_identity_verified(user_id: str, value_normalized: str) -> bool;
    def ensure_indexes -> None;
    def get_user_by_id(user_id: str) -> dict[str, any] | None;
    def delete_user(user_id: str) -> bool;
    def find_user_by_identity(value: str) -> dict[str, any] | None;
    def identity_taken(value: str) -> bool;
    def list_all_users(limit: int = 100, offset: int = 0) -> list[dict[str, any]];
    def get_user_by_sso(platform: str, external_id: str) -> dict[str, any] | None;
}

obj SqliteIdentityStorage(IdentityStorage) {
    has db_path: str,
        _engine: Engine postinit,
        _table: Table postinit,
        _identity_lookups: Table postinit,
        _sso_lookups: Table postinit;

    def postinit -> None;
    def _store_user(user_doc: dict[str, any]) -> None;
    def _update_fields(user_id: str, fields: dict[str, any]) -> bool;
    def _get_credentials(user_id: str) -> list[dict[str, any]];
    def _update_credentials(user_id: str, credentials: list[dict[str, any]]) -> None;
    def _get_identities(user_id: str) -> list[dict[str, any]];
    def _add_identity(user_id: str, identity: dict[str, any]) -> bool;
    def _remove_sso_identity(user_id: str, platform: str) -> bool;
    def _find_sso_link(platform: str, external_id: str) -> dict[str, any] | None;
    def _set_identity_verified(user_id: str, value_normalized: str) -> bool;
    def ensure_indexes -> None;
    def get_user_by_id(user_id: str) -> dict[str, any] | None;
    def delete_user(user_id: str) -> bool;
    def find_user_by_identity(value: str) -> dict[str, any] | None;
    def identity_taken(value: str) -> bool;
    def list_all_users(limit: int = 100, offset: int = 0) -> list[dict[str, any]];
    def get_user_by_sso(platform: str, external_id: str) -> dict[str, any] | None;
}
