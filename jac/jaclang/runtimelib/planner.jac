import os;
import inspect;
import dis;
import logging;
import from collections.abc { Generator }
import from functools { lru_cache }
import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, Archetype, NodeAnchor }
import from jaclang.runtimelib.query_plan { QueryPlan }

glob logger = logging.getLogger(__name__),
     __all__ = ['execute_plan', 'execute_path', 'plan_chain', 'plan_chain_ordered'];


obj _CodeKey {
    has filt: any,
        code: any by postinit,
        closure_types: tuple by postinit;

    def postinit -> None;
    def __hash__ -> int;
    def __eq__(other: object) -> bool;
}


@lru_cache(maxsize=None)
def _filter_type_name_by_code(key: _CodeKey) -> (str | None) {
    result: (str | None) = None;
    try {
        closure = inspect.getclosurevars(key.filt);
        for val in `list(closure.nonlocals.values()) + `list(
            closure.globals.values()
        ) {
            if isinstance(val, `type) and issubclass(val, Archetype) {
                result = val.__name__;
                break;
            }
        }
    } except Exception {
        ;
    }

    key.filt = None;
    return result;
}


@lru_cache(maxsize=None)
def _filter_has_predicates_by_code(code: any) -> bool {
    try {
        opcodes = {instr.opname for instr in dis.get_instructions(code)};
    } except (TypeError, AttributeError, ValueError) {
        return True;
    }
    return bool(opcodes & {'LOAD_ATTR', 'COMPARE_OP', 'CONTAINS_OP', 'IS_OP'});
}


def _filter_type_name(filt: any) -> (str | None);


def _filter_has_predicates(filt: any) -> bool;


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
