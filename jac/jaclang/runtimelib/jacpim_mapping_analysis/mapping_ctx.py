"""JacPIM Mapping Phase global context."""

import os

import jaclang.compiler.unitree as uni
from jaclang.runtimelib.archetype import NodeArchetype, WalkerArchetype
from jaclang.runtimelib.jacpim_mapping_analysis.data_mapper import (
    RandomPartitioner,
    RoundRobinPartitioner,
)
from jaclang.runtimelib.jacpim_mapping_analysis.temporal_trace_graph import (
    get_access_pattern_single_walker,
    get_ttg_from_ttt,
)
from jaclang.runtimelib.jacpim_static_analysis import JacPIMStaticCtx
from jaclang.runtimelib.jacpim_static_analysis.info_extract import extract_name

import networkx


def get_walker_code(walker: WalkerArchetype) -> uni.Archetype:
    """Get the walker type code from walker instance."""
    for walker_code in JacPIMStaticCtx.get_jac_program().mod.get_all_sub_nodes(
        uni.Archetype
    ):
        if walker_code.get_all_sub_nodes(uni.Name)[0].value == extract_name(walker):
            return walker_code
    raise ValueError(f"Walker code for {walker} not found in program.")


class JacPIMMappingCtx:
    """JacPIM Mapping Phase global context."""

    mapping: dict[NodeArchetype, int] | None
    ttg: networkx.MultiDiGraph | None
    partitioning: dict[int, int] | None

    @classmethod
    def setter(
        cls, nodes_and_walkers: list[tuple[NodeArchetype, WalkerArchetype]]
    ) -> None:
        """Set all the values in the context."""
        static_ctx = JacPIMStaticCtx
        cls.ttg = get_ttg_from_ttt(
            [
                get_access_pattern_single_walker(
                    start_node, static_ctx.get_networkx(), get_walker_code(walker)
                )
                for start_node, walker in nodes_and_walkers
            ]
        )
        cls.partitioning = None
        mapping_method = os.environ.get("MAPPING")
        if mapping_method is None:
            raise RuntimeError("Mapping method not specified")
        elif mapping_method == "JACPIM":
            cls.partitioning = RoundRobinPartitioner(
                cls.ttg, [start_node for start_node, _ in nodes_and_walkers]
            ).get_data_partitioning()
        elif mapping_method == "RANDOM":
            cls.partitioning = RandomPartitioner(
                cls.ttg, [start_node for start_node, _ in nodes_and_walkers]
            ).get_data_partitioning()
        else:
            raise RuntimeError("Mapping method undefined")

    @classmethod
    def get_ttg(cls) -> networkx.MultiDiGraph:
        """Read the Temporal Trace Graph."""
        if cls.ttg is None:
            raise RuntimeError("TTG is None!")
        return cls.ttg

    @classmethod
    def get_partitioning(cls) -> dict[int, int]:
        """Get the partitioning."""
        if cls.partitioning is None:
            raise RuntimeError("Partitioning not set.")
        else:
            return cls.partitioning
