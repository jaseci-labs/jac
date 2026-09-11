import logging;
import from uuid { UUID }

import from jaclang.runtime.graph_query { GraphQuery, QHop, QPred }

glob logger = logging.getLogger(__name__),
     __all__ = ['CompiledQuery', 'compile_query'];


obj CompiledQuery {
    has sql: str = '',
        params: dict[str, any] = {},
        residual: dict[int, list[QPred]] = {};
}


def compile_query(
    q: GraphQuery,
    upto: int,
    promotions: (dict[str, any] | None) = None,
    count_only: bool = False,
    acl_root: (str | None) = None
) -> CompiledQuery;
