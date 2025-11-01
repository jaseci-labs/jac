"""Plotting diagrams."""

from jaclang.runtimelib.jacpim_static_analysis.info_extract import (
    get_node_info_from_node_arch,
)

import matplotlib.pyplot as plt

import networkx as nx


def plot_ttg(graph: nx.MultiDiGraph, pos: dict, filename: str) -> None:
    """Plot and save one graph."""
    print(graph)
    plt.figure()
    nx.draw_networkx_nodes(graph, pos, node_size=100)
    display_names = {
        n: str(get_node_info_from_node_arch(graph.nodes[n]["archetype"]).display_name) + f"({n})"
        for n in graph.nodes()
    }
    edge_labels = {
        n: ", ".join(str(graph.edges[n]["ttg_attr"].timestamp)) for n in graph.edges
    }
    nx.draw_networkx_labels(graph, pos, display_names, font_size=10)
    nx.draw_networkx_edges(graph, pos)
    nx.draw_networkx_edge_labels(graph, pos, edge_labels, font_size=10)
    plt.savefig(filename, dpi=300)
    plt.close()
