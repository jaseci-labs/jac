"""Example of visualizing DOT file using streamlit-agraph and pygraphviz."""
import argparse;
import os;
import streamlit as st;

glob parser = argparse.ArgumentParser(description='Visualize DOT file');

with entry {
    parser.add_argument('dot_file', help='Path to the DOT file');
    try {
        args = parser.parse_args();
    } except SystemExit as e {
        exit_code = e.code if (e.code is not None) else 1;
        os._exit(exit_code if isinstance(exit_code, int) else 1);
    }
}

"""Parse DOT file and return nodes and edges as a tuple of dict and list respectively."""
def get_nodes_edges(dot_file: str) -> tuple[dict, list] {
    import pydot;
    import from streamlit_agraph { Edge, Node }

    graphs = pydot.graph_from_dot_file(dot_file);
    graph: pydot.Graph = graphs[0];
    node_list: list[pydot.Node] = graph.get_node_list();
    _nodes = {};
    for n in node_list {
        _nodes[n.get_name()] = Node(
            id=n.get_name(), label=n.get_label(), color='#DBEBC2'
        );
    }
    edge_list = graph.get_edge_list();
    _edges = [];
    for e in edge_list {
        _edges.append(
            Edge(
                source=e.get_source(), target=e.get_destination(), label=e.get_label()
            )
        );
    }
    return (_nodes, _edges);
}

with entry {
    st.title('Visualize DOT file');
}

glob selected_dot_file = args.dot_file,
     vis_opt = st.radio(
         'Visualization options',
         ['Use pygraphviz (Static)', 'Use streamlit-agraph (Interactive)']
     );

with entry {
    if selected_dot_file {
        if (vis_opt == 'Use pygraphviz (Static)') {
            with open(selected_dot_file) as f {
                st.graphviz_chart(f.read());
            }
        } elif (vis_opt == 'Use streamlit-agraph (Interactive)') {
            import from streamlit_agraph { ConfigBuilder, agraph }
            (nodes, edges) = get_nodes_edges(selected_dot_file);
            config_builder = ConfigBuilder(nodes);
            config = config_builder.build();
            return_value = agraph(list(nodes.values()), edges, config);
            if return_value {
                with st.expander('Selected Node Information', expanded=True) {
                    selected_node = nodes[return_value];
                    st.write('Node Id: ' + str(selected_node.id));
                    st.write('Node Label: ' + str(selected_node.label));
                    st.write('Node Color: ' + str(selected_node.color));
                }
            }
        }
    }
}
