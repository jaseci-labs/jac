import logging;
import from uuid { UUID }

import from jaclang.jac0core.graph_query { GraphQuery, QHop, QPred }

glob logger = logging.getLogger(__name__),
     __all__ = ['CompiledQuery', 'compile_query'];


obj CompiledQuery {
    has sql: str = '',
        params: dict = {},
        residual: dict[int, list[QPred]] = {};
}


def compile_query(q: GraphQuery, upto: int) -> CompiledQuery;
