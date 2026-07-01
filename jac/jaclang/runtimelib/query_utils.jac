import os;
import logging;
import inspect;
import dis;
import from uuid { UUID }
import from collections.abc { Callable }
import from functools { lru_cache }

import from jaclang.jac0core.archetype {
    Anchor,
    Archetype,
    NodeAnchor,
    ObjectSpatialPath
}
import from jaclang.runtimelib.memory { Memory }

glob logger = logging.getLogger(__name__),
     __all__ = [
         '_trace_enabled',
         '_filter_type_name',
         '_filter_has_predicates',
         '_materialize_ids',
         '_path_root_anchor'
     ];


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


def _trace_enabled -> bool;


def _filter_type_name(filt: (Callable[[Archetype], bool] | None)) -> (str | None);


def _filter_has_predicates(filt: (Callable[[Archetype], bool] | None)) -> bool;


def _materialize_ids(
    mem: Memory,
    ids: list[UUID],
    post_filter: (Callable[[Archetype], bool] | None) = None,
    slc: (slice | None) = None
) -> list[NodeAnchor];


def _path_root_anchor(mem: Memory, path: ObjectSpatialPath) -> (NodeAnchor | None);
