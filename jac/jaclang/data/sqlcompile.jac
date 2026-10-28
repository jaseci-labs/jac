import logging;
import from uuid { UUID }

glob logger = logging.getLogger(__name__),
     __all__ = ['CompiledQuery', 'compile_query'];


obj CompiledQuery {
    has sql: str = '',
        params: dict[str, any] = {},
        residual: dict[int, list[QPred]] = {},
        eresidual: dict[int, list[QPred]] = {};
}


def compile_query(
    q: GraphQuery,
    upto: int,
    store: Store,
    promotions: (dict[str, any] | None) = None,
    count_only: bool = False,
    acl_root: (str | None) = None,
    acl_residual: (dict[int, list[str]] | None) = None,
    residual_only: bool = False,
    group_by: (str | None) = None,
    edge_residual: (list[str] | None) = None,
    edge_acl: bool = False
) -> CompiledQuery;
