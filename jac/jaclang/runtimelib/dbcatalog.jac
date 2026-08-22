import logging;
import from enum { StrEnum }
import from jaclang.runtimelib.store { ConnInfo, SCHEMA_STAMP_KEY }

glob logger = logging.getLogger(__name__),
     REGISTRY_TABLE = 'jac_databases',
     MAINTENANCE_DB = 'postgres',
     DB_PREFIX = 'jac_',
     SCRATCH_PREFIX = 'jac_scratch_',
     DERIVED_TABLES = {'graph_types'},
     SCRATCH_HEARTBEAT_SECONDS = 60,
     UNREACHABLE_HOST_GRACE_SECONDS = 1800,
     LIVE_PID_GRACE_SECONDS = 86400,
     SCRATCH_CONDEMN_SEPARATION_SECONDS = 3600,
     __all__ = [
         'DbKind',
         'DbRecord',
         'DB_PREFIX',
         'DERIVED_TABLES',
         'LIVE_PID_GRACE_SECONDS',
         'MAINTENANCE_DB',
         'REGISTRY_TABLE',
         'SCRATCH_CONDEMN_SEPARATION_SECONDS',
         'SCRATCH_HEARTBEAT_SECONDS',
         'SCRATCH_PREFIX',
         'UNREACHABLE_HOST_GRACE_SECONDS',
         'admin_conninfo',
         'condemn_stale_scratch',
         'connect_admin',
         'dead_scratch_databases',
         'drop_database',
         'drop_if_still_dead',
         'ensure_registry',
         'expired_databases',
         'forget_database',
         'holds_no_data',
         'is_jac_database',
         'list_databases',
         'load_record',
         'process_alive',
         'record_database',
         'sqlstate_of',
         'start_heartbeat',
         'stop_heartbeat',
         'this_host',
         'touch_heartbeat'
     ];


enum DbKind(StrEnum) { PROJECT = 'project', SCRATCH = 'scratch' }


obj DbRecord {
    has database: str,
        size_bytes: int = 0,
        recorded: bool = False,
        kind: str = '',
        owner_path: str = '',
        host: str = '',
        pid: int = 0,
        created_at: str = '',
        last_used_at: str = '',
        heartbeat_age_seconds: int = -1,
        has_sessions: bool = False,
        condemned_age_seconds: int = -1;

    def is_scratch -> bool;
    def is_tracked_scratch -> bool;
    def is_dead_scratch -> bool;
    def pid_confirmed_dead -> bool;
    def heartbeat_stopped -> bool;
    def looks_abandoned -> bool;
    def dead_scratch_reason -> str;
    def is_orphaned -> bool;
    def state -> str;
}


def this_host -> str;
def is_jac_database(database: str) -> bool;
def sqlstate_of(err: Exception) -> str;
def admin_conninfo(info: ConnInfo) -> ConnInfo;
def connect_admin(info: ConnInfo) -> any;
def holds_no_data(info: ConnInfo, database: str) -> bool;
def ensure_registry(conn: any) -> bool;
def record_database(conn: any, database: str, kind: DbKind, owner_path: str) -> None;

def forget_database(conn: any, database: str) -> None;
def list_databases(conn: any) -> list[DbRecord];
def load_record(conn: any, database: str) -> (DbRecord | None);
def drop_database(conn: any, database: str, force: bool = False) -> bool;
def drop_if_still_dead(conn: any, database: str) -> bool;
def condemn_stale_scratch(conn: any, records: list[DbRecord]) -> list[str];
def process_alive(host: str, pid: int) -> bool;
def dead_scratch_databases(records: list[DbRecord]) -> list[str];
def expired_databases(conn: any, days: int, keep: str) -> list[str];
def touch_heartbeat(conn: any, database: str) -> bool;
def start_heartbeat(info: ConnInfo, database: str) -> None;
def stop_heartbeat(database: str) -> None;
