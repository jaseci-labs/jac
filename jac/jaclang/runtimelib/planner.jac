import logging;
import from uuid { UUID }

import from jaclang.runtimelib.query_plan { QueryPlan }

glob logger = logging.getLogger(__name__),
     __all__ = ['execute_plan', 'execute_path', 'plan_chain', 'plan_chain_ordered'];


def execute_plan(mem: any, plan: QueryPlan) -> list[any];


def execute_path(mem: any, path: any, slc: (slice | None) = None) -> list[any];


def plan_chain(
    root_anchor: any,
    origin_ids: set[UUID],
    chain: list[tuple[(str | None), (str | None), int]]
) -> (set[UUID] | None);


def plan_chain_ordered(
    root_anchor: any,
    origin_ids: set[UUID],
    chain: list[tuple[(str | None), (str | None), int]],
    slc: slice
) -> (list[UUID] | None);
