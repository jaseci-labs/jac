import logging;
import os;
import threading;
glob logger = logging.getLogger(__name__),
     _lock = threading.Lock(),
     _holder: dict[str, any] = {},
     NO_DATABASE_RESOLVED = (
         'no [scale.database] url / JAC_DB_URL resolved, and no project '
         'directory to provision an embedded server for'
     ),
     NO_DATABASE_IN_CLUSTER = (
         'no [scale.database] url / JAC_DB_URL resolved in a cluster, where an '
         'embedded server would be per-replica and lost on restart. point the '
         'deploy at a database'
     ),
     __all__ = [
         'scale_db_url',
         'shared_store',
         'shared_store_failure',
         'NO_DATABASE_RESOLVED',
         'NO_DATABASE_IN_CLUSTER'
     ];


def _after_fork_in_child;


with entry {
    if hasattr(os, 'register_at_fork') {
        os.register_at_fork(after_in_child=_after_fork_in_child);
    }
}


def scale_db_url -> (str | None);


def _url_source -> str;


def _store_target(store: any) -> str;


def _in_cluster -> bool;


def _fail(reason: str);


def shared_store_failure -> (str | None);


def shared_store -> (any | None);


def _failure_reason(stage: str, source: str, store: any, e: Exception) -> str;
