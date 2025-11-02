"""Generate visit sequence for one walker."""

from dataclasses import dataclass
from typing import Generator, TypeAlias

import jaclang.compiler.unitree as uni


@dataclass
class VisitInfo:
    """A struct that stores the visit key information."""

    from_node_type: str
    walker_type: str
    edge_type: str
    async_edge: bool


VisitSequence: TypeAlias = list[VisitInfo]
_TracingInfo: TypeAlias = list[uni.UniCFGNode]

def visit_sequence_start_by(seq_a: VisitSequence, seq_b: VisitSequence) -> bool:
    """Check if seq_a starts with seq_b."""
    if len(seq_a) < len(seq_b):
        return False
    for i in range(len(seq_b)):
        if seq_a[i] != seq_b[i]:
            return False
    return True


def get_visit_sequences(ability: uni.Ability) -> Generator[list[VisitInfo], None, None]:
    """Get visit sequences for one ability."""
    stack: list[_TracingInfo] = [[ability]]
    while len(stack) > 0:
        path = stack.pop()
        node = path[-1]
        new_nodes = [new_node for new_node in node.bb_out if new_node not in path]
        new_paths = [path + [new_node] for new_node in new_nodes]
        for new_path in new_paths:
            new_node = new_path[-1]
            if len(new_node.bb_out) == 0:
                res = [
                    _get_visit_info(new_node)
                    for new_node in new_path
                    if isinstance(new_node, uni.VisitStmt)
                ] + [
                    _get_par_visit_info(new_node)
                    for new_node in new_path
                    if isinstance(new_node, uni.FuncCall)
                ]
                yield [v for v in res if v is not None]
            else:
                stack.append(new_path)


def _get_par_visit_info(par_visit_stmt: uni.FuncCall) -> VisitInfo | None:
    """Get the visit info of a par_visit statement."""
    print(f"DEBUG: Processing par_visit statement: {par_visit_stmt}")
    if not par_visit_stmt.get_all_sub_nodes(uni.AtomTrailer):
        return None
    names = par_visit_stmt.get_all_sub_nodes(uni.AtomTrailer)[0].get_all_sub_nodes(
        uni.Name
    )
    if all(name.value != "par_visit" for name in names):
        return None
    res = VisitInfo(
        from_node_type=_get_from_node_type_of_visit(par_visit_stmt),
        walker_type=_get_walker_type_from_visit(par_visit_stmt),
        edge_type=_get_to_edge_type_of_visit(par_visit_stmt),
        async_edge=True,
    )
    return res


def _get_from_node_type_of_visit(visit_stmt: uni.VisitStmt | uni.FuncCall) -> str:
    """Get the node type that the visit is from.

    For example, if a visit is in an ability:
        can xxx with XXX entry {...}, it will return XXX
    """
    ability = visit_stmt.parent_of_type(uni.Ability)
    return (
        ability.get_all_sub_nodes(uni.EventSignature)[0]
        .get_all_sub_nodes(uni.Name)[0]
        .value
    )


def _get_to_edge_type_of_visit(visit_stmt: uni.VisitStmt | uni.FuncCall) -> str:
    filters = visit_stmt.get_all_sub_nodes(uni.FilterCompr)
    if len(filters) == 0:
        return "GenericEdge"
    return filters[0].get_all_sub_nodes(uni.Name)[0].value


def _get_walker_type_from_visit(visit_stmt: uni.VisitStmt | uni.FuncCall) -> str:
    return visit_stmt.parent_of_type(uni.Archetype).get_all_sub_nodes(uni.Name)[0].value


def _get_visit_info(visit_stmt: uni.VisitStmt) -> VisitInfo:
    """Get the visit statement information."""
    from_node = _get_from_node_type_of_visit(visit_stmt)
    edge_type = _get_to_edge_type_of_visit(visit_stmt)
    walker_type = _get_walker_type_from_visit(visit_stmt)
    res = VisitInfo(
        from_node_type=from_node,
        walker_type=walker_type,
        edge_type=edge_type,
        async_edge=False,
    )
    return res

def remove_redundant_visit_sequences(
    visit_sequences: list[VisitSequence],
) -> list[VisitSequence]:
    """Remove redundant visit sequences, redundant sequence means it is a prefix of another sequence."""
    # Sort by length descending
    visit_sequences.sort(key=lambda seq: len(seq), reverse=True)
    non_redundant_seqs: list[VisitSequence] = []
    for seq in visit_sequences:
        if not any(visit_sequence_start_by(other_seq, seq) for other_seq in non_redundant_seqs):
            non_redundant_seqs.append(seq)
    return non_redundant_seqs


def get_walker_info(walker: uni.Archetype) -> dict[str, list[list[VisitInfo]]]:
    """Get the visit info of a walker."""
    visit_info: dict[str, list[list[VisitInfo]]] = {}
    abilities = walker.get_all_sub_nodes(uni.Ability)
    for ability in abilities:
        if len(ability.get_all_sub_nodes(uni.EventSignature)) == 0:
            continue
        name = (
            ability.get_all_sub_nodes(uni.EventSignature)[0]
            .get_all_sub_nodes(uni.Name)[0]
            .value
        )
        # visit_info[name] = list(get_visit_sequences(ability))
        visit_info[name] = remove_redundant_visit_sequences(
            list(get_visit_sequences(ability))
        )
    print(visit_info)
    return visit_info
