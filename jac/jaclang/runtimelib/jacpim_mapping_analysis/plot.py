"""Plotting diagrams."""

from jaclang.runtimelib.jacpim_mapping_analysis.mapping_ctx import JacPIMMappingCtx
from jaclang.runtimelib.jacpim_static_analysis.info_extract import (
    get_node_info_from_node_arch,
)

import matplotlib.pyplot as plt

import matplotlib.pyplot as plt

import networkx as nx


def plot_ttg(graph: nx.MultiDiGraph, pos: dict, filename: str) -> None:
    """Plot and save one graph."""
    print(graph)
    plt.figure()
    colors = ["red", "blue", "green", "orange", "purple", "brown", "pink", "gray"]
    partitioning = JacPIMMappingCtx.get_partitioning()
    node_colors = [colors[partitioning[n] % len(colors)] for n in graph.nodes()]

    nx.draw_networkx_nodes(graph, pos, node_color=node_colors, node_size=100)

    display_names = {
        n: str(get_node_info_from_node_arch(graph.nodes[n]["archetype"]).display_name)
        for n in graph.nodes()
    }
    assert all(
        "ttg_attr" in graph.edges[n] for n in graph.edges
    ), "Edge attribute 'ttg_attr' missing in some edges."
    # All Edges have timestamp
    assert all(
        hasattr(graph.edges[n]["ttg_attr"], "timestamp") for n in graph.edges
    ), "Edge attribute 'timestamp' missing in some edges."

    # All Edges have timestamp not empty
    assert all(
        graph.edges[n]["ttg_attr"].timestamp is not None for n in graph.edges
    ), "Edge attribute 'timestamp' is None in some edges."
    assert all( len(str(graph.edges[n]["ttg_attr"].timestamp)) > 0 for n in graph.edges
    ), "Edge attribute 'timestamp' is empty in some edges."
    edge_labels = {
        n: ", ".join(str(graph.edges[n]["ttg_attr"].timestamp)) for n in graph.edges
    }
    
    nx.draw_networkx_labels(graph, pos, display_names, font_size=10)
    nx.draw_networkx_edges(graph, pos)
    nx.draw_networkx_edge_labels(graph, pos, edge_labels, font_size=10)
    plt.savefig(filename, dpi=300)
    plt.close()
