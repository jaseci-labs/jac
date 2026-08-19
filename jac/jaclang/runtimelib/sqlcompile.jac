import logging;
import from uuid { UUID }

import from jaclang.jac0core.graph_query { GraphQuery, QHop, QPred }

glob logger = logging.getLogger(__name__),
     __all__ = ['CompiledQuery', 'compile_query', 'chain_relational_ok'];


obj CompiledQuery {
    has sql: str = '',
        params: dict = {},
        residual: dict[int, list[QPred]] = {};
}


def compile_query(q: GraphQuery, upto: int, relational: bool = False) -> CompiledQuery;

def chain_relational_ok(q: GraphQuery, upto: int) -> bool;
